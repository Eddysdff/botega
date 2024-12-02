
local INITIAL_MODULES = { ".crypto.mac.hmac", "string", ".crypto.cipher.morus", "debug", ".handlers", ".crypto.padding.zero", ".crypto.digest.sha2_256", ".crypto.digest.md2", ".crypto.util.hex", ".default", ".eval", ".crypto.util.bit", ".utils", ".crypto.util.stream", "_G", "json", ".crypto.cipher.norx", ".base64", ".crypto.cipher.aes256", ".crypto.digest.md4", ".crypto.util.queue", ".stringify", ".handlers-utils", ".crypto.cipher.issac", "utf8", ".crypto.cipher.aes", ".dump", ".process", ".crypto.cipher.mode.cfb", "ao", ".pretty", ".crypto.digest.sha1", "coroutine", ".crypto.cipher.aes128", ".crypto.init", ".crypto.digest.sha2_512", ".crypto.cipher.aes192", ".crypto.kdf.pbkdf2", ".crypto.mac.init", ".crypto.digest.init", "package", "table", ".crypto.cipher.mode.ctr", ".crypto.util.array", "bit32", ".crypto.cipher.mode.ecb", ".crypto.kdf.init", ".assignment", ".crypto.cipher.mode.cbc", ".crypto.digest.blake2b", ".crypto.digest.sha3", ".crypto.digest.md5", ".crypto.cipher.mode.ofb", "io", "os", ".chance", ".crypto.util.init", ".crypto.cipher.init" }
      
local function isInitialModule(value)
    for _, v in ipairs(INITIAL_MODULES) do
        if v == value then
            return true
        end
    end
    return false
end

for k, _ in pairs(package.loaded) do
    if not isInitialModule(k) then
        package.loaded[k] = nil
    end
end

    
    DexiTokenProcess = "atlyT9ph8ex_TxDDkQ2fdbhVT62sLw6boJPdEr7UqJE"
    
    do
local _ENV = _ENV
package.preload[ "amm.amm-handlers" ] = function( ... ) local arg = _G.arg;
local token = require("amm.token.token")
local responses = require("utils.responses")
require("subscriptions.subscribable")


local mod = {}

function mod.handleGetInfo(msg)
   local replyData = { Subscriptions = Subscribable.getInfo() }
   local replyTags = token.info()
   responses.sendReply(msg, replyData, replyTags)
end

return mod
end
end

do
local _ENV = _ENV
package.preload[ "amm.pool.burn" ] = function( ... ) local arg = _G.arg;
local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local assert = _tl_compat and _tl_compat.assert or assert; local debug = _tl_compat and _tl_compat.debug or debug; local pcall = _tl_compat and _tl_compat.pcall or pcall; local string = _tl_compat and _tl_compat.string or string; local assertions = require("utils.assertions")
local balances = require("amm.token.balance")
local outputs = require("utils.output")
local bint = require("utils.tl-bint")(256)
local pool = require("amm.pool.pool")
local json = require("json")
require("amm.pool.globals")








local function executeBurn(quantity, sender)
   local totalSupply = balances.totalSupply()
   local pair = pool.getPair()
   local tokenA, tokenB = pair[1], pair[2]

   assert(
   assertions.isTokenQuantity(quantity),
   "Invalid burn quantity")


   assert(Balances[sender] ~= nil, "No balance for this user")
   assert(bint.ule(quantity, Balances[sender]), "Not enough tokens to burn")



   local function burnRatioOf(inReserve)
      return bint.udiv(quantity * inReserve, totalSupply)
   end

   local tokenAQty = burnRatioOf(Reserves[tokenA])
   Reserves[tokenA] = Reserves[tokenA] - tokenAQty

   local tokenBQty = burnRatioOf(Reserves[tokenB])
   Reserves[tokenB] = Reserves[tokenB] - tokenBQty

   Balances[sender] = Balances[sender] - quantity

   return {
      burnedPoolTokens = quantity,
      withdrawnTokenA = tokenAQty,
      withdrawnTokenB = tokenBQty,
      totalSupply = totalSupply,
   }
end

local function burn(message)
   local quantity = bint(message.Tags.Quantity)
   local sender = message.From
   local pair = pool.getPair()
   local tokenA, tokenB = pair[1], pair[2]

   local burnResult = executeBurn(quantity, sender)

   ao.send({
      Target = tokenB,
      Action = "Transfer",
      Recipient = sender,
      Quantity = tostring(burnResult.withdrawnTokenB),
   })

   ao.send({
      Target = tokenA,
      Action = "Transfer",
      Recipient = sender,
      Quantity = tostring(burnResult.withdrawnTokenA),
   })

   ao.send({
      Target = ao.env.Process.Tags["AMM-Factory"],
      ["Relay-To"] = sender,
      Action = "Burn-Confirmation",
      ["Burn-Quantity"] = tostring(burnResult.burnedPoolTokens),
      ["Burned-Pool-Tokens"] = tostring(burnResult.burnedPoolTokens),
      ["Withdrawn-" .. tokenA] = tostring(burnResult.withdrawnTokenA),
      ["Withdrawn-" .. tokenB] = tostring(burnResult.withdrawnTokenB),
      ["Token-A"] = tokenA,
      ["Token-B"] = tokenB,
      ['Token-A-Quantity'] = tostring(burnResult.withdrawnTokenA),
      ['Token-B-Quantity'] = tostring(burnResult.withdrawnTokenB),
   })

   ao.send({
      Target = sender,
      Action = "Debit-Notice",
      Recipient = ao.id,
      Quantity = tostring(burnResult.burnedPoolTokens),
   })


   local liquidityChangeMessage = {
      ["Reserves-Token-A"] = tostring(Reserves[tokenA]),
      ["Reserves-Token-B"] = tostring(Reserves[tokenB]),
      ["Delta-Token-A"] = tostring(-burnResult.withdrawnTokenA),
      ["Delta-Token-B"] = tostring(-burnResult.withdrawnTokenB),
      ["Action"] = "Burn",
      ["Delta-Pool-Tokens"] = tostring(-burnResult.burnedPoolTokens),
      ["Total-Pool-Tokens"] = tostring(burnResult.totalSupply),
      ["Token-A"] = tokenA,
      ["Token-B"] = tokenB,
      ["Original-Message-Id"] = message.Id,
      ["Address"] = sender,
      ["Transfer-Quantity"] = tostring(burnResult.burnedPoolTokens),
      ["Recipient"] = sender,
      ["Sender"] = ao.id,
   }

   Subscribable.notifyTopic('liquidity-add-remove', liquidityChangeMessage)

   print(
   outputs.prefix("Burn", message.From) ..
   Colors.blue ..
   tostring(quantity) ..
   " " ..
   Colors.green ..
   "POOL TOKENS" ..
   Colors.gray ..
   " → " ..
   Colors.blue ..
   tostring(burnResult.withdrawnTokenA) ..
   " " ..
   outputs.formatAddress(tokenA) ..
   Colors.gray ..
   " + " ..
   Colors.blue ..
   tostring(burnResult.withdrawnTokenB) ..
   " " ..
   outputs.formatAddress(tokenB))

end

local function burnWithCatch(message)
   local status, result = pcall(burn, message)

   if not status then
      local traceback = debug.traceback()
      print("!!! Error: " .. 'burn' .. json.encode(traceback))

      local err = string.gsub(result, "%[[%w_.\" ]*%]:%d*: ", "")

      ao.send({
         Target = ao.env.Process.Tags["AMM-Factory"],
         ["Relay-To"] = message.From,
         Action = "Burn-Error",
         ["Result"] = err,
         ["Burn-Id"] = message.Id,
         ["Burn-Quantity"] = message.Tags.Quantity,
      })
   end
end

return {
   executeBurn = executeBurn,
   burn = burn,
   burnWithCatch = burnWithCatch,
}
end
end

do
local _ENV = _ENV
package.preload[ "amm.pool.cancel" ] = function( ... ) local arg = _G.arg;
local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local assert = _tl_compat and _tl_compat.assert or assert; local assertions = require("utils.assertions")
local outputs = require("utils.output")
local provide = require("amm.pool.provide")
local utils = require("utils.tl-utils")
require("amm.pool.globals")

local function cancel(message)

   local transferID = message.Tags.Transfer

   assertions.isAddress(transferID)

   local transfer = utils.find(
   function(val) return val.id == transferID end,
   PendingProvides)


   assert(transfer ~= nil, "Could not find provided transfer")
   assert(transfer.sender == message.From, "Transfer owner is not the caller")


   ao.send({
      Target = transfer.token,
      Action = "Transfer",
      Recipient = transfer.sender,
      Quantity = tostring(transfer.quantity),
   })


   provide.closePending({ id = transfer.id })


   ao.send({
      Target = transfer.sender,
      Action = "Refund-Notice",
      Transfer = transfer.id,
      Quantity = tostring(transfer.quantity),
   })


   print(
   outputs.prefix("Cancel", message.From) ..
   Colors.gray ..
   "Sending back " ..
   Colors.blue ..
   tostring(transfer.quantity) ..
   " " ..
   outputs.formatAddress(transfer.token) ..
   Colors.gray ..
   " to " ..
   outputs.formatAddress(transfer.sender))

end

return {
   cancel = cancel,
}
end
end

do
local _ENV = _ENV
package.preload[ "amm.pool.globals" ] = function( ... ) local arg = _G.arg;
require('utils.tl-bint')
require('subscriptions.subscribable')

PendingProvideType = {}














FeeDiscountTier = {}



TFeeDiscountWhitelist = {}





AmmFees = {}




TFeeDiscountsPerTier = {}


FeeValues = {}






return {}
end
end

do
local _ENV = _ENV
package.preload[ "amm.pool.pool" ] = function( ... ) local arg = _G.arg;
local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local assert = _tl_compat and _tl_compat.assert or assert; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local math = _tl_compat and _tl_compat.math or math; local table = _tl_compat and _tl_compat.table or table; local assertions = require("utils.assertions")
local outputs = require("utils.output")
local bint = require("utils.tl-bint")(256)
local utils = require("utils.tl-utils")
local bintmath = require("utils.bintmath")
local responses = require("utils.responses")

require('amm.pool.globals')


FEE_VALUES = {
   regular = {
      lpFee = 0.25,
      protocolFee = 0,
   },
   discounts = {
      ['portfolio-agent'] = {
         lpFee = 0.02,
         protocolFee = 0,
      },
   },
}

local pool = {}



function pool.getPair()

   local tokenA = ao.env.Process.Tags["Token-A"]


   local tokenB = ao.env.Process.Tags["Token-B"]

   return { tokenA, tokenB }
end


function pool.getReserves()
   return Reserves
end



function pool.K()
   local pair = pool.getPair()

   return Reserves[pair[1]] * Reserves[pair[2]]
end

function pool.getLPFeePercentage(tier)
   if tier then
      return FEE_VALUES.discounts[tier].lpFee
   end


   return FEE_VALUES.regular.lpFee
end

function pool.getProtocolFeePercentage(tier)
   if tier then
      return FEE_VALUES.discounts[tier].protocolFee
   end


   return FEE_VALUES.regular.protocolFee
end

function pool.getFeesAsPercentages(tier)
   local lp = pool.getLPFeePercentage(tier)
   local protocol = pool.getProtocolFeePercentage(tier)
   local total = lp + protocol

   return {
      ["LP-Fee-Percentage"] = tostring(lp),
      ["Protocol-Fee-Percentage"] = tostring(protocol),
      ["Fee-Percentage"] = tostring(total),
   }
end

TotalFeeForSubscriber = {}



function pool.getTotalFeeForSubscriber()
   return {
      TotalFee = tostring(pool.getLPFeePercentage() + pool.getProtocolFeePercentage()),
   }
end

function pool.getFeeDiscountTier(swapper)
   local discountTiers = FeeDiscountWhitelist[swapper]
   if not discountTiers then

      return nil
   end

   if #discountTiers == 0 then
      ao.send({
         Target = ao.id,
         Action = 'Log-Warning',
         Warning = 'Account ' .. swapper .. 'is whitelisted for a fee discount but has 0 DiscountTiers associated. Removing entry',
      })
      FeeDiscountWhitelist[swapper] = nil
      return
   end

   local bestTier = utils.reduce(
   function(acc, el)
      return FEE_VALUES.discounts[el].lpFee < FEE_VALUES.discounts[acc].lpFee and el or acc
   end,
   discountTiers[1],
   discountTiers)

   return bestTier
end


ReservesForSubscriber = {}






function pool.getReservesForSubscriber()
   local pair = pool.getPair()

   return {
      ["Reserves-Token-A"] = tostring(Reserves[pair[1]]),
      ["Reserves-Token-B"] = tostring(Reserves[pair[2]]),
      ["Token-A"] = pair[1],
      ["Token-B"] = pair[2],
   }
end


function pool.getCollector()
   return FeeCollector
end





function pool.getOutput(input, token)

   local pair = pool.getPair()


   local K = pool.K()


   local otherToken = utils.find(
   function(val) return val ~= token end,
   pair)








   local out = Reserves[otherToken] - bintmath.div_round_up(K, (Reserves[token] + input))

   return out
end

function pool.deductFees(inputQty, swapper)
   local feeDiscountTier = pool.getFeeDiscountTier(swapper)

   local lpFeePercent = pool.getLPFeePercentage(feeDiscountTier)
   local protocolFeePercent = pool.getProtocolFeePercentage(feeDiscountTier)

   local precisionMultiplier = 100


   local qtyExcludingFees = inputQty * bint(math.floor((100 - lpFeePercent - protocolFeePercent) * precisionMultiplier))

   local incomingQtyFeeAdjusted = bint.udiv(
   qtyExcludingFees,
   bint(100 * precisionMultiplier))


   local totalFees = inputQty - incomingQtyFeeAdjusted
   local totalFeePercent = protocolFeePercent + lpFeePercent
   local lpFeeRatio = totalFeePercent == 0 and 1 or lpFeePercent / totalFeePercent
   local lpFee = bint.udiv(totalFees * bint(math.ceil(100 * lpFeeRatio)), bint(100))
   local protocolFee = totalFees - lpFee
   return incomingQtyFeeAdjusted, lpFee, protocolFee, feeDiscountTier
end



function pool.getPrice(msg)

   local token = msg.Tags.Token


   local pair = pool.getPair()

   if not utils.includes(token, pair) then
      local replyData = nil
      local replyTags = { Price = "0" }
      responses.sendReply(msg, replyData, replyTags)

      print(
      outputs.prefix("Get-Price", msg.From) ..
      Colors.gray ..
      "Price = " ..
      Colors.blue ..
      "0" ..
      Colors.reset)

      return
   end


   assert(
   msg.Tags.Quantity == nil or assertions.isTokenQuantity(msg.Tags.Quantity),
   "Invalid quantity")



   local quantity = msg.Tags.Quantity and bint(msg.Tags.Quantity) or bint.one()


   local price = pool.getOutput(quantity, token)

   local replyData = nil
   local replyTags = { Price = tostring(price) }
   responses.sendReply(msg, replyData, replyTags)
   print(
   outputs.prefix("Get-Price", msg.From) ..
   Colors.gray ..
   "Price = " ..
   Colors.blue ..
   tostring(price) ..
   Colors.reset)

end


function pool.getSwapOutput(msg)

   local tokenIn = msg.Tags.Token


   local pair = pool.getPair()

   if not utils.includes(tokenIn, pair) then
      responses.sendError(msg, "Unknown token")

      print(
      outputs.prefix("Get-Output", msg.From) ..
      Colors.gray ..
      "Error = " ..
      Colors.blue ..
      "Unknown Token" ..
      Colors.reset)

      return
   end

   local quantityAsString = msg.Tags.Quantity
   if not assertions.isTokenQuantity(quantityAsString) then
      error("Please provide a valid 'Quantity' tag for the swap input")
   end
   local quantity = bint(quantityAsString)

   local swapper = msg.Tags.Swapper
   assertions.isAddress(
   swapper,
   "'Swapper' tag must contain a valid address. Use address '0000000000000000000000000000000000000000000' if you need the output for an account without fee discounts")


   local qtyAfterFees, lpFeeQty, protocolFeeQty, feeDiscountTier = pool.deductFees(quantity, swapper)


   local output = pool.getOutput(qtyAfterFees, tokenIn)

   local replyData = nil
   local replyTags = {
      Output = tostring(output),
      ["Quantity-After-Fees"] = tostring(qtyAfterFees),
      ["LP-Fee-Quantity"] = tostring(lpFeeQty),
      ["Protocol-Fee-Quantity"] = tostring(protocolFeeQty),
      ["Fee-Discount-Tier"] = feeDiscountTier and tostring(feeDiscountTier),
   }
   responses.sendReply(msg, replyData, replyTags)
   print(
   outputs.prefix("Get-Swap-Output", msg.From) ..
   Colors.gray ..
   "Output = " ..
   Colors.blue ..
   tostring(output) ..
   Colors.reset)

end


function pool.init()
   local pair = pool.getPair()


   if Reserves then
      Reserves = {
         [pair[1]] = bint(tostring(Reserves[pair[1]])),
         [pair[2]] = bint(tostring(Reserves[pair[2]])),
      }
   else
      Reserves = {
         [pair[1]] = bint.zero(),
         [pair[2]] = bint.zero(),
      }
   end

   if PendingProvides then
      for _, pp in ipairs(PendingProvides) do
         pp.quantity = bint(tostring(pp.quantity))
      end
   else
      PendingProvides = {}
   end

   FeeDiscountWhitelist = FeeDiscountWhitelist or {}

   print(
   Colors.gray ..
   "Pool was set up for pair: " ..
   outputs.formatAddress(pair[1]) ..
   Colors.gray ..
   "/" ..
   outputs.formatAddress(pair[2]))

end







function pool.slippageLimit(tolerance, expected, limit)

   assert(limit == "lower" or limit == "upper", "Invalid limit type")


   if limit == "lower" then tolerance = -tolerance end


   local multiplier = 100
   local multipliedPercentage = (100 + tolerance) * multiplier


   return bint.udiv(
   expected * bint(multipliedPercentage),
   bint(100 * multiplier))

end



function pool.addWhitelistedForFeeDiscount(feeTier, address)
   local discountTiers = FeeDiscountWhitelist[address]
   if not discountTiers then
      FeeDiscountWhitelist[address] = { feeTier }
      return
   end

   local sameTier = utils.find(
   function(v) return v == feeTier end,
   discountTiers)


   if not sameTier then
      table.insert(discountTiers, feeTier)
   end
end

function pool.removeWhitelistedForFeeDiscount(feeTier, address)
   local discountTiers = FeeDiscountWhitelist[address]
   if not discountTiers then
      return
   end

   local sameTier = utils.find(
   function(v) return v == feeTier end,
   discountTiers)


   if not sameTier then
      return
   end

   FeeDiscountWhitelist[address] = utils.filter(
   function(v) return v ~= feeTier end,
   discountTiers)

end


function pool.handleWhitelistForFeeDiscount(msg)
   assert(
   msg.From == Owner or msg.From == ao.id, "Only the owner or self can operate the whitelist")


   local feeDiscountTier = msg.Tags["Tier"]
   assertions.isFeeDiscountTier(feeDiscountTier)
   local address = msg.Tags["Address"]
   assertions.isAddress(address)
   pool.addWhitelistedForFeeDiscount(
   msg.Tags["Tier"],
   msg.Tags["Address"])

end

function pool.handleGetWhitelistedForFeeDiscount(msg)
   local address = msg.Tags["Address"]
   assertions.isAddress(address)
   local discountTiers = FeeDiscountWhitelist[address]
   if not discountTiers then
      msg.reply({
         Target = msg.From,
         Action = "Resp-Whitelisted-For-Fee-Discount",
         ["Whitelisted-For-Fee-Discount"] = "No",
      })
      return
   end

   msg.reply({
      Target = msg.From,
      Action = "Resp-Whitelisted-For-Fee-Discount",
      ["Whitelisted-For-Fee-Discount"] = "Yes",
      ["Discount-Tiers"] = require("json").encode(discountTiers),
   })
end

function pool.handleUnWhitelistForFeeDiscount(msg)
   assert(
   msg.From == Owner or msg.From == ao.id, "Only the owner or self can operate the whitelist")


   local feeDiscountTier = msg.Tags["Tier"]
   assertions.isFeeDiscountTier(feeDiscountTier)
   local address = msg.Tags["Address"]
   assertions.isAddress(address)
   pool.removeWhitelistedForFeeDiscount(
   msg.Tags["Tier"],
   msg.Tags["Address"])

end

return pool
end
end

do
local _ENV = _ENV
package.preload[ "amm.pool.provide" ] = function( ... ) local arg = _G.arg;
local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local assert = _tl_compat and _tl_compat.assert or assert; local table = _tl_compat and _tl_compat.table or table; local assertions = require("utils.assertions")
local bintmath = require("utils.bintmath")
local balance = require("amm.token.balance")
local outputs = require("utils.output")
local bint = require("utils.tl-bint")(256)
local pool = require("amm.pool.pool")
local utils = require("utils.tl-utils")
require("amm.pool.globals")
require("subscriptions.subscribable")











local function findPendingProvide(sender)
   return utils.find(
   function(val)
      return val.sender == sender
   end,
   PendingProvides)

end






local function closePending(data)
   if not data.sender and not data.id then return end

   PendingProvides = utils.filter(
   function(val)
      if data.id then
         return val.id ~= data.id
      end

      return val.sender ~= data.sender
   end,
   PendingProvides) or
   {}
end

local function replacePendingProvide(pendingProvide, qtyB, sender, tokenB)
   local newPendingProvide = {
      id = pendingProvide.id,
      token = tokenB,
      quantity = pendingProvide.quantity + qtyB,
      sender = sender,
   }
   closePending({ id = pendingProvide.id })
   table.insert(PendingProvides, newPendingProvide)
end

local function createNewPendingProvide(message, qtyB, sender, tokenB)
   table.insert(PendingProvides, {
      id = message.Id,
      token = tokenB,
      quantity = qtyB,
      sender = sender,
   })
end

local function attemptAdjustBalances(qtyA, qtyB, tokenA, tokenB, slippageTolerance)

   local limitB = pool.slippageLimit(slippageTolerance, qtyB, "lower")
   local optimalB = bint.udiv(Reserves[tokenB] * qtyA, Reserves[tokenA])




   if bint.ule(optimalB, qtyB) and bint.ule(limitB, optimalB) then

      qtyB = optimalB
   else

      local limitA = pool.slippageLimit(slippageTolerance, qtyA, "lower")
      local optimalA = bint.udiv(Reserves[tokenA] * qtyB, Reserves[tokenB])






      assert(
      bint.ule(optimalA, qtyA) and bint.ule(limitA, optimalA),
      "Could not provide liquidity within the given slippage tolerance")



      qtyA = optimalA
   end

   return qtyA, qtyB
end

local refundExtraTokens = function(initialQuantity, actualQuantity, token, sender)
   if bint.ult(actualQuantity, initialQuantity) then
      ao.send({
         Target = token,
         Action = "Transfer",
         Recipient = sender,
         Quantity = tostring(initialQuantity - actualQuantity),
      })
   end
end

local function calculateLpTokensToMint(qtyA, tokenA)






   return bint.udiv(
   balance.totalSupply() * qtyA,
   Reserves[tokenA])

end


local function executeProvide(tokenA, tokenB, qtyA, qtyB, sender, slippageTolerance)

   assert(
   assertions.isSlippagePercentage(slippageTolerance),
   "Invalid slippage tolerance percentage")



   assert(
   bint.isbint(qtyA) and bint.isbint(qtyB),
   "Quantity is not bint")


   assert(
   Reserves[tokenA] ~= nil and Reserves[tokenB] ~= nil,
   "Token not found in reserves")


   assert(
   qtyA:gt(bint.zero()) and qtyB:gt(bint.zero()),
   "Quantity is not greater than 0")



   local poolIsEmpty = bint.eq(Reserves[tokenA], bint.zero()) and bint.eq(Reserves[tokenB], bint.zero())


   local ratioMatches = bint.eq(
   qtyA * Reserves[tokenB],
   qtyB * Reserves[tokenA])


   local lpTokensToMint = bint.zero()

   if poolIsEmpty then



      lpTokensToMint = bintmath.sqrt(qtyA * qtyB)
   elseif ratioMatches then

      lpTokensToMint = calculateLpTokensToMint(qtyA, tokenA)
   else


      qtyA, qtyB = attemptAdjustBalances(qtyA, qtyB, tokenA, tokenB, slippageTolerance)
      lpTokensToMint = calculateLpTokensToMint(qtyA, tokenA)
   end


   assert(lpTokensToMint:ge(bint.zero()), "Too little liquidity provided")


   Balances[sender] = (Balances[sender] or bint.zero()) + lpTokensToMint


   Reserves[tokenA] = Reserves[tokenA] + qtyA
   Reserves[tokenB] = Reserves[tokenB] + qtyB

   return {
      lpTokensMinted = bint(lpTokensToMint),
      actualQuantityA = bint(qtyA),
      actualQuantityB = bint(qtyB),
   }
end



local ProvideReturnType = {}









local function notifySubscribers(message, provideTokenA, provideResult, recipient)
   local pair = pool.getPair()
   local tokenA, tokenB = pair[1], pair[2]

   local deltaTokenA
   local deltaTokenB

   if provideTokenA == tokenA then
      deltaTokenA = provideResult.actualQuantityA
      deltaTokenB = provideResult.actualQuantityB
   else
      deltaTokenA = provideResult.actualQuantityB
      deltaTokenB = provideResult.actualQuantityA
   end

   local liquidityChangeMessage = {
      ["Reserves-Token-A"] = tostring(Reserves[tokenA]),
      ["Reserves-Token-B"] = tostring(Reserves[tokenB]),
      ["Delta-Token-A"] = tostring(deltaTokenA),
      ["Delta-Token-B"] = tostring(deltaTokenB),
      ["Action"] = "Provide",
      ["Delta-Pool-Tokens"] = tostring(provideResult.lpTokensMinted),
      ["Total-Pool-Tokens"] = tostring(balance.totalSupply()),
      ["Token-A"] = tokenA,
      ["Token-B"] = tokenB,
      ["Original-Message-Id"] = message.Id,
      ["Address"] = recipient,
      ["Transfer-Quantity"] = tostring(provideResult.lpTokensMinted),
      ["Recipient"] = recipient,
      ["Sender"] = ao.id,
   }


   Subscribable.notifyTopic('liquidity-add-remove', liquidityChangeMessage)
end



local function provide(message)


   local tokenB = message.From


   local sender = message.Tags.Sender

   local initialQuantityB = bint(message.Tags.Quantity)

   local slippageTolerance = tonumber(message.Tags["X-Slippage-Tolerance"]) or 0




   local pendingProvide = findPendingProvide(sender)

   if not pendingProvide then
      createNewPendingProvide(message, initialQuantityB, sender, tokenB)
      return
   end

   local foundPendingProvide = pendingProvide
   if foundPendingProvide and foundPendingProvide.token == tokenB then
      replacePendingProvide(pendingProvide, initialQuantityB, sender, tokenB)
      return
   end

   local initialQuantityA = foundPendingProvide.quantity
   local tokenA = foundPendingProvide.token


   local provideResult = executeProvide(
   tokenA, tokenB, initialQuantityA, initialQuantityB, sender, slippageTolerance)





   refundExtraTokens(initialQuantityA, provideResult.actualQuantityA, tokenA, sender)
   refundExtraTokens(initialQuantityB, provideResult.actualQuantityB, tokenB, sender)


   closePending({ sender = sender })


   ao.send({
      Target = ao.env.Process.Tags["AMM-Factory"],
      ["Relay-To"] = sender,
      Action = "Provide-Confirmation",
      ["Provide-Id"] = message.Id,
      ["Received-Pool-Tokens"] = tostring(provideResult.lpTokensMinted),
      ['Token-A'] = tokenA,
      ['Token-B'] = tokenB,
      ["Provided-" .. tokenA] = tostring(provideResult.actualQuantityA),
      ["Provided-" .. tokenB] = tostring(provideResult.actualQuantityB),
      ['Token-A-Quantity'] = tostring(provideResult.actualQuantityA),
      ['Token-B-Quantity'] = tostring(provideResult.actualQuantityB),
   })

   ao.send({
      Target = sender,
      Action = "Credit-Notice",
      Sender = ao.id,
      Quantity = tostring(provideResult.lpTokensMinted),
   })

   notifySubscribers(message, tokenA, provideResult, sender)


   print(
   outputs.prefix("Provide", sender) ..
   Colors.blue ..
   tostring(provideResult.actualQuantityA) ..
   " " ..
   outputs.formatAddress(tokenA) ..
   Colors.gray ..
   " + " ..
   Colors.blue ..
   tostring(provideResult.actualQuantityB) ..
   " " ..
   outputs.formatAddress(tokenB) ..
   Colors.gray ..
   " → " ..
   Colors.blue ..
   tostring(provideResult.lpTokensMinted) ..
   " " ..
   Colors.green ..
   "POOL TOKENS" ..
   Colors.reset)



   return {
      Reserves = Reserves,
      Balances = Balances,
      lpTokensToMint = provideResult.lpTokensMinted,
      qtyA = provideResult.actualQuantityA,
      qtyB = provideResult.actualQuantityB,
      ['Provide-Id'] = message.Id,
   }
end



return {
   provide = provide,
   executeProvide = executeProvide,
   findPendingProvide = findPendingProvide,
   closePending = closePending,
   replacePendingProvide = replacePendingProvide,
   createNewPendingProvide = createNewPendingProvide,
   ProvideReturnType = ProvideReturnType,
}
end
end

do
local _ENV = _ENV
package.preload[ "amm.pool.refund" ] = function( ... ) local arg = _G.arg;
local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local assert = _tl_compat and _tl_compat.assert or assert; local outputs = require("utils.output")
local provide = require("amm.pool.provide")
local pool = require("amm.pool.pool")
local utils = require("utils.tl-utils")
local bintModule = require("utils.tl-bint")
local bint = bintModule(256)

local mod = {}







function mod.refund(message)


   if not RefundError then return end



   assert(message.Tags["X-Action"] == "Swap" or message.Tags["X-Action"] == "Provide", 'invalid refund action')
   local action = message.Tags["X-Action"]



   local sourceInteractionIDs = {
      Swap = "Order",
      Provide = "Provide",
   }


   local sender = message.Tags.Sender


   ao.send({
      Target = message.From,
      Action = "Transfer",
      Recipient = sender,
      Quantity = message.Tags.Quantity,
      ["X-Refund-Reason"] = RefundError,
      ["X-Refunded-Transfer"] = message.Tags["Pushed-For"],
      ["X-Refunded-" .. sourceInteractionIDs[action]] = message.Id,
   })



   local errorMessage = {
      Target = ao.env.Process.Tags["AMM-Factory"],
      ["Relay-To"] = sender,
      ["Response-For"] = action,
      [sourceInteractionIDs[action] .. "-Id"] = message.Id,
      Result = RefundError,
   }



   if action == "Provide" then

      local pendingProvide = utils.find(

      function(val) return val.sender == sender end,
      PendingProvides)





      if pendingProvide then

         local foundPendingProvide = pendingProvide
         ao.send({
            Target = foundPendingProvide.token,
            Action = "Transfer",
            Recipient = sender,
            Quantity = tostring(foundPendingProvide.quantity),
            ["X-Refunded-Transfer"] = foundPendingProvide.id,
            ["X-Refunded-" .. sourceInteractionIDs[action]] = message.Id,
         })

         errorMessage.Action = "Provide-Error"
         errorMessage['Token-A'] = message.From
         errorMessage['Token-B'] = foundPendingProvide.token
         errorMessage['Token-A-Quantity'] = message.Tags.Quantity
         errorMessage['Token-B-Quantity'] = tostring(bint(foundPendingProvide.quantity))


         provide.closePending({ id = foundPendingProvide.id })
      end
   else
      local pair = pool.getPair()

      errorMessage.Action = "Order-Error"
      errorMessage['From-Token'] = message.From
      errorMessage['From-Quantity'] = message.Tags.Quantity
      errorMessage['To-Token'] = message.From == pair[1] and pair[2] or pair[1]
      errorMessage['To-Quantity'] = message.Tags["X-Expected-Min-Output"]
   end


   ao.send(errorMessage)


   print(
   outputs.prefix("Refund", sender) ..
   Colors.gray ..
   "Refunding " ..
   Colors.blue ..
   action ..
   " " ..
   Colors.gray ..
   "(" ..
   RefundError ..
   ")" ..
   Colors.reset)





   RefundError = nil
end

return mod
end
end

do
local _ENV = _ENV
package.preload[ "amm.pool.swap" ] = function( ... ) local arg = _G.arg;
local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local assert = _tl_compat and _tl_compat.assert or assert; local outputs = require("utils.output")
local bint = require("utils.tl-bint")(256)
local pool = require("amm.pool.pool")
require("amm.pool.globals")
require("subscriptions.subscribable")
local json = require("json")

local mod = {}














function mod.executeSwapWithMinOutput(inputToken, inputQty, expectedMinOutput, swapper)
   local pair = pool.getPair()
   local tokenA, tokenB = pair[1], pair[2]

   assert(
   inputQty:gt(bint.zero()),
   "Invalid input quantity")



   assert(
   expectedMinOutput:gt(bint.zero()),
   "Invalid expected min output")



   assert(
   bint.ult(bint.zero(), Reserves[tokenA]) and bint.ult(bint.zero(), Reserves[tokenB]),
   "The reserves are empty")



   local incomingQtyFeeAdjusted, lpFeeQty, protocolFeeQty, feeDiscountTier = pool.deductFees(inputQty, swapper)


   local outputToken = inputToken == tokenA and tokenB or tokenA


   local outputQty = pool.getOutput(
   incomingQtyFeeAdjusted,
   inputToken)



   local newReserves = {
      [tokenA] = Reserves[tokenA],
      [tokenB] = Reserves[tokenB],
   }




   newReserves[inputToken] = newReserves[inputToken] + incomingQtyFeeAdjusted + lpFeeQty
   newReserves[outputToken] = newReserves[outputToken] - outputQty


   assert(bint.ult(bint.zero(), newReserves[outputToken]), "This swap would drain the pool")


   assert(
   bint.ult(bint.zero(), outputQty),
   "There isn't enough liquidity in the reserves to complete this order")




   assert(
   bint.ule(expectedMinOutput, outputQty),
   "Could not swap with expected min output")



   Reserves[tokenA] = newReserves[tokenA]
   Reserves[tokenB] = newReserves[tokenB]

   return {
      outputQty = bint(outputQty),
      totalFeeQty = bint(lpFeeQty + protocolFeeQty),
      lpFeeQty = bint(lpFeeQty),
      protocolFeeQty = bint(protocolFeeQty),
      outputToken = outputToken,
      inputToken = inputToken,
      inputQty = bint(inputQty),
      newReserves = newReserves,
      feeDiscountTier = feeDiscountTier,
   }
end

function mod.swapWithMinOutput(message)
   local expectedMinOutput = bint(message.Tags["X-Expected-Min-Output"])


   local inputQty = bint(message.Tags.Quantity)


   local inputToken = message.From
   local swapper = message.Tags.Sender

   local swapResult = mod.executeSwapWithMinOutput(inputToken, inputQty, bint(expectedMinOutput), swapper)

   return swapResult
end



function mod.swap(message)
   local pair = pool.getPair()

   assert(not message.Tags["X-Expected-Output"], "X-Expected-Output is disabled, use X-Expected-Min-Output instead")
   assert(pair[1] == message.From or pair[2] == message.From, "This pool does not support this token")

   local swapResult
   if message.Tags["X-Expected-Min-Output"] then
      swapResult = mod.swapWithMinOutput(message)
   else
      error("X-Expected-Min-Output is not present")
   end

   local sender = message.Tags.Sender


   ao.send({
      Target = swapResult.outputToken,
      Action = "Transfer",
      Recipient = sender,
      Quantity = tostring(swapResult.outputQty),
      ['X-Action'] = "Swap-Output",
   })


   ao.send({
      Target = swapResult.inputToken,
      Action = "Transfer",
      Recipient = pool.getCollector(),
      Quantity = tostring(swapResult.protocolFeeQty),
   })

   local payload = {
      ["Order-Id"] = message.Id,
      ["From-Token"] = swapResult.inputToken,
      ["From-Quantity"] = tostring(swapResult.inputQty),
      ["To-Token"] = swapResult.outputToken,
      ["To-Quantity"] = tostring(swapResult.outputQty),
      ["Reserves-Token-A"] = tostring(Reserves[pair[1]]),
      ["Reserves-Token-B"] = tostring(Reserves[pair[2]]),
      ["Token-A"] = pair[1],
      ["Token-B"] = pair[2],
      ["Fee-Percentage"] = tostring(pool.getFeesAsPercentages(swapResult.feeDiscountTier)["Fee-Percentage"]),
      ["Total-Fee"] = tostring(swapResult.totalFeeQty),
      ["LP-Fee"] = tostring(swapResult.lpFeeQty),
      ["Protocol-Fee"] = tostring(swapResult.protocolFeeQty),
      ["User"] = sender,
   }


   local msgPayload = json.decode(json.encode(payload))
   msgPayload.Target = ao.env.Process.Tags["AMM-Factory"]
   msgPayload["Relay-To"] = sender
   msgPayload["Action"] = "Order-Confirmation"
   ao.send(msgPayload)


   local topicPayload = json.decode(json.encode(payload))
   Subscribable.notifyTopic('order-confirmation', topicPayload)


   print(
   outputs.prefix("Swap", sender) ..
   Colors.blue ..
   tostring(swapResult.inputQty) ..
   " " ..
   outputs.formatAddress(swapResult.inputToken) ..
   Colors.gray ..
   " → " ..
   Colors.blue ..
   tostring(swapResult.outputQty) ..
   " " ..
   outputs.formatAddress(swapResult.outputToken) ..
   Colors.reset)

end

return mod
end
end

do
local _ENV = _ENV
package.preload[ "amm.token.balance" ] = function( ... ) local arg = _G.arg;
local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local pairs = _tl_compat and _tl_compat.pairs or pairs; local assertions = require("utils.assertions")
local outputs = require("utils.output")
local bint = require("utils.tl-bint")(256)
local utils = require("utils.tl-utils")
local json = require("json")
local responses = require("utils.responses")

require("amm.token.globals")




local function balance(msg)

   local target = msg.Tags.Target or msg.From


   assertions.isAddress(target)

   local bal = Balances[target] or bint.zero()

   local replyData = tostring(bal)
   local replyTags = {
      Balance = tostring(bal),
      Ticker = Ticker,
   }
   responses.sendReply(msg, replyData, replyTags)

   print(
   outputs.prefix("Balance", msg.From) ..
   Colors.gray ..
   "Balance = " ..
   Colors.blue ..
   tostring(bal) ..
   Colors.reset)

end



local function balances(msg)


   local rawBalances = {}

   for addr, bal in pairs(Balances) do
      rawBalances[addr] = tostring(bal)
   end

   local replyData = rawBalances
   local replyTags = { Ticker = Ticker }
   responses.sendReply(msg, replyData, replyTags)

   print(
   outputs.prefix("Balances", msg.From) ..
   Colors.gray ..
   "See response data" ..
   Colors.reset)

end


local function totalSupply()
   local r = utils.reduce(
   function(acc, val) return acc + val end,
   bint.zero(),
   utils.values(Balances))

   return r
end



local function toSubUnits(val)
   return val * bint.ipow(bint(10), bint(Denomination))
end

return {
   balance = balance,
   balances = balances,
   totalSupply = totalSupply,
   toSubUnits = toSubUnits,
}
end
end

do
local _ENV = _ENV
package.preload[ "amm.token.credit_notice" ] = function( ... ) local arg = _G.arg;
local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local assert = _tl_compat and _tl_compat.assert or assert; local assertions = require("utils.assertions")
local pool = require("amm.pool.pool")
local utils = require("utils.tl-utils")

local mod = {}



function mod.creditNotice(message)

   local rawQuantity = message.Tags.Quantity


   assert(
   assertions.isTokenQuantity(rawQuantity),
   "Invalid token quantity")



   local token = message.From


   local XAction = message.Tags["X-Action"] or "No-Action"


   local pair = pool.getPair()


   local actions = { "Swap", "Provide" }



   if utils.includes(token, pair) and utils.includes(XAction, actions) then
      return
   end

   if (token == Subscribable.PAYMENT_TOKEN and XAction == "Pay-For-Subscription") then
      return
   end


   local sender = message.Tags.Sender



   ao.send({
      Target = token,
      Action = "Transfer",
      Recipient = sender,
      Quantity = rawQuantity,
      ["X-Action"] = utils.includes(XAction, actions) and (XAction .. "-Error") or "Credit-Notice-Error",
      ["X-Error"] = utils.includes(XAction, actions) and "Token is not in pair" or "Invalid forwarded action",
   })
end

return mod
end
end

do
local _ENV = _ENV
package.preload[ "amm.token.globals" ] = function( ... ) local arg = _G.arg;
require("utils.tl-bint")








return {}
end
end

do
local _ENV = _ENV
package.preload[ "amm.token.token" ] = function( ... ) local arg = _G.arg;
local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local pairs = _tl_compat and _tl_compat.pairs or pairs; local outputs = require("utils.output")
local bint = require("utils.tl-bint")(256)
local balance = require("amm.token.balance")
require("amm.token.globals")













local function init()

   if Balances then
      for k, v in pairs(Balances) do
         Balances[k] = bint(tostring(v))
      end
   else
      Balances = {
         [ao.id] = bint.zero(),
      }
   end

   Name = Name or ao.env.Process.Tags["Name"]
   Ticker = Ticker or ao.env.Process.Tags["Name"]
   Denomination = Denomination or 12
   Logo = Logo or "fTKfocxQs94bj444uVDiVKSZQ8bKu4rqkx5hHhjIYrw"

   print(
   Colors.gray ..
   "Token was set up: " ..
   outputs.formatAddress(ao.id))

end

local function info()

   return {
      Name = Name,
      Ticker = Ticker,
      Logo = Logo,
      Denomination = tostring(Denomination),
      TotalSupply = tostring(balance.totalSupply()),
      Type = "AMM",
      TokenA = ao.env.Process.Tags["Token-A"],
      TokenB = ao.env.Process.Tags["Token-B"],
   }
end

return {
   init = init,
   info = info,
}
end
end

do
local _ENV = _ENV
package.preload[ "amm.token.transfer" ] = function( ... ) local arg = _G.arg;
local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local assert = _tl_compat and _tl_compat.assert or assert; local pairs = _tl_compat and _tl_compat.pairs or pairs; local string = _tl_compat and _tl_compat.string or string; local assertions = require("utils.assertions")
local outputs = require("utils.output")
local bint = require("utils.tl-bint")(256)
local pool = require("amm.pool.pool")
local balance = require("amm.token.balance")

require("amm.token.globals")

local mod = {}


function mod.transfer(message)

   local target = message.Tags.Recipient or message.Target


   assertions.isAddress(target)


   assert(target ~= message.From, "Target cannot be the sender")


   assert(
   assertions.isTokenQuantity(message.Tags.Quantity),
   "Invalid transfer quantity")



   local quantity = bint(message.Tags.Quantity)


   assert(Balances[message.From] ~= nil, "No balance for this user")
   assert(bint.ule(quantity, Balances[message.From]), "Not enought tokens for this transfer")


   Balances[target] = (Balances[target] or bint.zero()) + quantity
   Balances[message.From] = Balances[message.From] - quantity

   if not message.Tags.Cast then

      local debitNotice = {
         Target = message.From,
         Action = "Debit-Notice",
         Recipient = target,
         Quantity = tostring(quantity),
      }
      local creditNotice = {
         Target = target,
         Action = "Credit-Notice",
         Sender = message.From,
         Quantity = tostring(quantity),
      }


      for tagName, tagValue in pairs(message.Tags) do

         if string.sub(tagName, 1, 2) == "X-" then
            debitNotice[tagName] = tagValue
            creditNotice[tagName] = tagValue
         end
      end


      ao.send(debitNotice)
      ao.send(creditNotice)


      local pair = pool.getPair()
      local tokenA, tokenB = pair[1], pair[2]
      local liquidityChangeMessage = {
         ["Reserves-Token-A"] = tostring(Reserves[tokenA]),
         ["Reserves-Token-B"] = tostring(Reserves[tokenB]),
         ["Delta-Token-A"] = tostring(0),
         ["Delta-Token-B"] = tostring(0),
         ["Action"] = "Transfer",
         ["Delta-Pool-Tokens"] = tostring(0),
         ["Total-Pool-Tokens"] = tostring(balance.totalSupply()),
         ["Token-A"] = tokenA,
         ["Token-B"] = tokenB,
         ["Original-Message-Id"] = message.Id,
         ["Transfer-Quantity"] = tostring(quantity),
         ["Recipient"] = target,
         ["Sender"] = message.From,
      }
      Subscribable.notifyTopic('liquidity-add-remove', liquidityChangeMessage)


   end

   print(
   outputs.prefix("Transfer", message.From) ..
   Colors.blue ..
   tostring(quantity) ..
   Colors.gray ..
   " " ..
   Ticker ..
   " to " ..
   outputs.formatAddress(target) ..
   Colors.reset)

end

return mod
end
end

do
local _ENV = _ENV
package.preload[ "subscriptions.subscribable" ] = function( ... ) local arg = _G.arg;
package.loaded["pkg-api"] = nil
package.loaded["storage-vanilla"] = nil
package.loaded["storage-db"] = nil
do
  local _ENV = _ENV
  package.preload["pkg-api"] = function(...)
    local arg = _G.arg;
    local json = require("json")
    local bint = require(".bint")(256)

    local function newmodule(pkg)
      --[[
    {
      topic: string = eventCheckFn: () => boolean
    }
  ]]
      pkg.TopicsAndChecks = pkg.TopicsAndChecks or {}


      pkg.PAYMENT_TOKEN = '8p7ApPZxC_37M06QHVejCQrKsHbcJEerd3jWNkDUWPQ'
      pkg.PAYMENT_TOKEN_TICKER = 'BRKTST'


      -- REGISTRATION

      function pkg.sendReply(msg, data, tags)
        msg.reply({
          Action = msg.Tags.Action .. "-Response",
          Tags = tags,
          Data = json.encode(data)
        })
      end

      function pkg.sendConfirmation(target, action, tags)
        ao.send({
          Target = target,
          Action = action .. "-Confirmation",
          Tags = tags,
          Status = 'OK'
        })
      end

      function pkg.registerSubscriber(processId, whitelisted)
        local subscriberData = pkg._storage.getSubscriber(processId)

        if subscriberData then
          error('Process ' ..
            processId ..
            ' is already registered as a subscriber.')
        end

        pkg._storage.registerSubscriber(processId, whitelisted)

        pkg.sendConfirmation(
          processId,
          'Register-Subscriber',
          { Whitelisted = tostring(whitelisted) }
        )
      end

      function pkg.handleRegisterSubscriber(msg)
        local processId = msg.From

        pkg.registerSubscriber(processId, false)
        pkg._subscribeToTopics(msg, processId)
      end

      function pkg.handleRegisterWhitelistedSubscriber(msg)
        if msg.From ~= Owner and msg.From ~= ao.id then
          error('Only the owner or the process itself is allowed to register whitelisted subscribers')
        end

        local processId = msg.Tags['Subscriber-Process-Id']

        if not processId then
          error('Subscriber-Process-Id is required')
        end

        pkg.registerSubscriber(processId, true)
        pkg._subscribeToTopics(msg, processId)
      end

      function pkg.handleGetSubscriber(msg)
        local processId = msg.Tags['Subscriber-Process-Id']
        local replyData = pkg._storage.getSubscriber(processId)
        pkg.sendReply(msg, replyData)
      end

      pkg.updateBalance = function(processId, amount, isCredit)
        local subscriber = pkg._storage.getSubscriber(processId)
        if not isCredit and not subscriber then
          error('Subscriber ' .. processId .. ' is not registered. Register first, then make a payment')
        end

        if not isCredit and bint(subscriber.balance) < bint(amount) then
          error('Insufficient balance for subscriber ' .. processId .. ' to be debited')
        end

        pkg._storage.updateBalance(processId, amount, isCredit)
      end

      function pkg.handleReceivePayment(msg)
        local processId = msg.Tags["X-Subscriber-Process-Id"]

        local error
        if not processId then
          error = "No subscriber specified"
        end

        if msg.From ~= pkg.PAYMENT_TOKEN then
          error = "Wrong token. Payment token is " .. (pkg.PAYMENT_TOKEN or "?")
        end

        if error then
          ao.send({
            Target = msg.From,
            Action = 'Transfer',
            Recipient = msg.Sender,
            Quantity = msg.Quantity,
            ["X-Action"] = "Subscription-Payment-Refund",
            ["X-Details"] = error
          })

          ao.send({
            Target = msg.Sender,
            Action = "Pay-For-Subscription-Error",
            Status = "ERROR",
            Error = error
          })
          return
        end

        pkg.updateBalance(msg.Tags.Sender, msg.Tags.Quantity, true)

        pkg.sendConfirmation(msg.Sender, 'Pay-For-Subscription')

        print('Received subscription payment from ' ..
          msg.Tags.Sender .. ' of ' .. msg.Tags.Quantity .. ' ' .. msg.From .. " (" .. pkg.PAYMENT_TOKEN_TICKER .. ")")
      end

      function pkg.handleSetPaymentToken(msg)
        pkg.PAYMENT_TOKEN = msg.Tags.Token
      end

      -- TOPICS

      function pkg.configTopicsAndChecks(cfg)
        pkg.TopicsAndChecks = cfg
      end

      function pkg.getTopicsInfo()
        local topicsInfo = {}
        for topic, _ in pairs(pkg.TopicsAndChecks) do
          local topicInfo = pkg.TopicsAndChecks[topic]
          topicsInfo[topic] = {
            description = topicInfo.description,
            returns = topicInfo.returns,
            subscriptionBasis = topicInfo.subscriptionBasis
          }
        end

        return topicsInfo
      end

      function pkg.getInfo()
        return {
          paymentTokenTicker = pkg.PAYMENT_TOKEN_TICKER,
          paymentToken = pkg.PAYMENT_TOKEN,
          topics = pkg.getTopicsInfo()
        }
      end

      -- SUBSCRIPTIONS

      function pkg._subscribeToTopics(msg, processId)
        assert(msg.Tags['Topics'], 'Topics is required')

        local topics = json.decode(msg.Tags['Topics'])

        pkg.onlyRegisteredSubscriber(processId)

        pkg._storage.subscribeToTopics(processId, topics)

        local subscriber = pkg._storage.getSubscriber(processId)

        pkg.sendConfirmation(
          processId,
          'Subscribe-To-Topics',
          { ["Updated-Topics"] = json.encode(subscriber.topics) }
        )
      end

      -- same for regular and whitelisted subscriptions - the subscriber must call it
      function pkg.handleSubscribeToTopics(msg)
        local processId = msg.From
        pkg._subscribeToTopics(msg, processId)
      end

      function pkg.unsubscribeFromTopics(processId, topics)
        pkg.onlyRegisteredSubscriber(processId)

        pkg._storage.unsubscribeFromTopics(processId, topics)

        local subscriber = pkg._storage.getSubscriber(processId)

        pkg.sendConfirmation(
          processId,
          'Unsubscribe-From-Topics',
          { ["Updated-Topics"] = json.encode(subscriber.topics) }
        )
      end

      function pkg.handleUnsubscribeFromTopics(msg)
        assert(msg.Tags['Topics'], 'Topics is required')

        local processId = msg.From
        local topics = msg.Tags['Topics']

        pkg.unsubscribeFromTopics(processId, topics)
      end

      -- NOTIFICATIONS

      -- core dispatch functionality

      function pkg.notifySubscribers(topic, payload)
        local targets = pkg._storage.getTargetsForTopic(topic)
        for _, target in ipairs(targets) do
          ao.send({
            Target = target,
            Action = 'Notify-On-Topic',
            Topic = topic,
            Data = json.encode(payload)
          })
        end
      end

      -- notify without check

      function pkg.notifyTopics(topicsAndPayloads, timestamp)
        for topic, payload in pairs(topicsAndPayloads) do
          payload.timestamp = timestamp
          pkg.notifySubscribers(topic, payload)
        end
      end

      function pkg.notifyTopic(topic, payload, timestamp)
        return pkg.notifyTopics({
          [topic] = payload
        }, timestamp)
      end

      -- notify with configured checks

      function pkg.checkNotifyTopics(topics, timestamp)
        for _, topic in ipairs(topics) do
          local shouldNotify = pkg.TopicsAndChecks[topic].checkFn()
          if shouldNotify then
            local payload = pkg.TopicsAndChecks[topic].payloadFn()
            payload.timestamp = timestamp
            pkg.notifySubscribers(topic, payload)
          end
        end
      end

      function pkg.checkNotifyTopic(topic, timestamp)
        return pkg.checkNotifyTopics({ topic }, timestamp)
      end

      -- HELPERS

      pkg.onlyRegisteredSubscriber = function(processId)
        local subscriberData = pkg._storage.getSubscriber(processId)
        if not subscriberData then
          error('process ' .. processId .. ' is not registered as a subscriber')
        end
      end
    end

    return newmodule
  end
end

do
  local _ENV = _ENV
  package.preload["storage-db"] = function(...)
    local arg = _G.arg;
    local sqlite3 = require("lsqlite3")
    local bint = require(".bint")(256)
    local json = require("json")

    local function newmodule(pkg)
      local mod = {}
      pkg._storage = mod

      local sql = {}

      DB = DB or sqlite3.open_memory()

      sql.create_subscribers_table = [[
    CREATE TABLE IF NOT EXISTS subscribers (
        process_id TEXT PRIMARY KEY,
        topics TEXT,  -- treated as JSON (an array of strings)
        balance TEXT,
        whitelisted INTEGER NOT NULL, -- 0 or 1 (false or true)
    );
  ]]

      local function createTableIfNotExists()
        DB:exec(sql.create_subscribers_table)
        print("Err: " .. DB:errmsg())
      end

      createTableIfNotExists()

      -- REGISTRATION & BALANCES

      ---@param whitelisted boolean
      function mod.registerSubscriber(processId, whitelisted)
        local stmt = DB:prepare [[
    INSERT INTO subscribers (process_id, balance, whitelisted)
    VALUES (:process_id, :balance, :whitelisted)
  ]]
        if not stmt then
          error("Failed to prepare SQL statement for registering process: " .. DB:errmsg())
        end
        stmt:bind_names({
          process_id = processId,
          balance = "0",
          whitelisted = whitelisted and 1 or 0
        })
        local _, err = stmt:step()
        stmt:finalize()
        if err then
          error("Err: " .. DB:errmsg())
        end
      end

      function mod.getSubscriber(processId)
        local stmt = DB:prepare [[
    SELECT * FROM subscribers WHERE process_id = :process_id
  ]]
        if not stmt then
          error("Failed to prepare SQL statement for checking subscriber: " .. DB:errmsg())
        end
        stmt:bind_names({ process_id = processId })
        local result = sql.queryOne(stmt)
        if result then
          result.whitelisted = result.whitelisted == 1
          result.topics = json.decode(result.topics)
        end
        return result
      end

      function sql.updateBalance(processId, amount, isCredit)
        local currentBalance = bint(sql.getBalance(processId))
        local diff = isCredit and bint(amount) or -bint(amount)
        local newBalance = tostring(currentBalance + diff)

        local stmt = DB:prepare [[
    UPDATE subscribers
    SET balance = :new_balance
    WHERE process_id = :process_id
  ]]
        if not stmt then
          error("Failed to prepare SQL statement for updating balance: " .. DB:errmsg())
        end
        stmt:bind_names({
          process_id = processId,
          new_balance = newBalance,
        })
        local result, err = stmt:step()
        stmt:finalize()
        if err then
          error("Error updating balance: " .. DB:errmsg())
        end
      end

      function sql.getBalance(processId)
        local stmt = DB:prepare [[
    SELECT * FROM subscribers WHERE process_id = :process_id
  ]]
        if not stmt then
          error("Failed to prepare SQL statement for getting balance entry: " .. DB:errmsg())
        end
        stmt:bind_names({ process_id = processId })
        local row = sql.queryOne(stmt)
        return row and row.balance or "0"
      end

      -- SUBSCRIPTION

      function sql.subscribeToTopics(processId, topics)
        -- add the topics to the existing topics while avoiding duplicates
        local stmt = DB:prepare [[
    UPDATE subscribers
    SET topics = (
        SELECT json_group_array(topic)
        FROM (
            SELECT json_each.value as topic
            FROM subscribers, json_each(subscribers.topics)
            WHERE process_id = :process_id

            UNION

            SELECT json_each.value as topic
            FROM json_each(:topics)
        )
    )
    WHERE process_id = :process_id;
  ]]
        if not stmt then
          error("Failed to prepare SQL statement for subscribing to topics: " .. DB:errmsg())
        end
        stmt:bind_names({
          process_id = processId,
          topic = topics
        })
        local _, err = stmt:step()
        stmt:finalize()
        if err then
          error("Err: " .. DB:errmsg())
        end
      end

      function sql.unsubscribeFromTopics(processId, topics)
        -- remove the topics from the existing topics
        local stmt = DB:prepare [[
    UPDATE subscribers
    SET topics = (
        SELECT json_group_array(topic)
        FROM (
            SELECT json_each.value as topic
            FROM subscribers, json_each(subscribers.topics)
            WHERE process_id = :process_id

            EXCEPT

            SELECT json_each.value as topic
            FROM json_each(:topics)
        )
    )
    WHERE process_id = :process_id;
  ]]
        if not stmt then
          error("Failed to prepare SQL statement for unsubscribing from topics: " .. DB:errmsg())
        end
        stmt:bind_names({
          process_id = processId,
          topic = topics
        })
        local _, err = stmt:step()
        stmt:finalize()
        if err then
          error("Err: " .. DB:errmsg())
        end
      end

      -- NOTIFICATIONS

      function mod.activationCondition()
        return [[
    (subs.whitelisted = 1 OR subs.balance <> "0")
  ]]
      end

      function sql.getTargetsForTopic(topic)
        local activationCondition = mod.activationCondition()
        local stmt = DB:prepare [[
    SELECT process_id
    FROM subscribers as subs
    WHERE json_contains(topics, :topic) AND ]] .. activationCondition

        if not stmt then
          error("Failed to prepare SQL statement for getting notifiable subscribers: " .. DB:errmsg())
        end
        stmt:bind_names({ topic = topic })
        return sql.queryMany(stmt)
      end

      -- UTILS

      function sql.queryMany(stmt)
        local rows = {}
        for row in stmt:nrows() do
          table.insert(rows, row)
        end
        stmt:reset()
        return rows
      end

      function sql.queryOne(stmt)
        return sql.queryMany(stmt)[1]
      end

      function sql.rawQuery(query)
        local stmt = DB:prepare(query)
        if not stmt then
          error("Err: " .. DB:errmsg())
        end
        return sql.queryMany(stmt)
      end

      return sql
    end

    return newmodule
  end
end

do
  local _ENV = _ENV
  package.preload["storage-vanilla"] = function(...)
    local arg = _G.arg;
    local bint = require ".bint" (256)
    local json = require "json"
    local utils = require ".utils"

    local function newmodule(pkg)
      local mod = {
        Subscribers = pkg._storage and pkg._storage.Subscribers or {} -- we preserve state from previously used package
      }

      --[[
    mod.Subscribers :
    {
      processId: ID = {
        topics: string, -- JSON (string representation of a string[])
        balance: string,
        whitelisted: number -- 0 or 1 -- if 1, receives data without the need to pay
      }
    }
  ]]

      pkg._storage = mod

      -- REGISTRATION & BALANCES

      function mod.registerSubscriber(processId, whitelisted)
        mod.Subscribers[processId] = mod.Subscribers[processId] or {
          balance = "0",
          topics = json.encode({}),
          whitelisted = whitelisted and 1 or 0,
        }
      end

      function mod.getSubscriber(processId)
        local data = json.decode(json.encode(mod.Subscribers[processId]))
        if data then
          data.whitelisted = data.whitelisted == 1
          data.topics = json.decode(data.topics)
        end
        return data
      end

      function mod.updateBalance(processId, amount, isCredit)
        local current = bint(mod.Subscribers[processId].balance)
        local diff = isCredit and bint(amount) or -bint(amount)
        mod.Subscribers[processId].balance = tostring(current + diff)
      end

      -- SUBSCRIPTIONS

      function mod.subscribeToTopics(processId, topics)
        local existingTopics = json.decode(mod.Subscribers[processId].topics)

        for _, topic in ipairs(topics) do
          if not utils.includes(topic, existingTopics) then
            table.insert(existingTopics, topic)
          end
        end
        mod.Subscribers[processId].topics = json.encode(existingTopics)
      end

      function mod.unsubscribeFromTopics(processId, topics)
        local existingTopics = json.decode(mod.Subscribers[processId].topics)
        for _, topic in ipairs(topics) do
          existingTopics = utils.filter(
            function(t)
              return t ~= topic
            end,
            existingTopics
          )
        end
        mod.Subscribers[processId].topics = json.encode(existingTopics)
      end

      -- NOTIFICATIONS

      function mod.getTargetsForTopic(topic)
        local targets = {}
        for processId, v in pairs(mod.Subscribers) do
          local mayReceiveNotification = mod.hasEnoughBalance(processId) or v.whitelisted == 1
          if mod.isSubscribedTo(processId, topic) and mayReceiveNotification then
            table.insert(targets, processId)
          end
        end
        return targets
      end

      -- HELPERS

      mod.hasEnoughBalance = function(processId)
        return mod.Subscribers[processId] and bint(mod.Subscribers[processId].balance) > 0
      end

      mod.isSubscribedTo = function(processId, topic)
        local subscription = mod.Subscribers[processId]
        if not subscription then return false end

        local topics = json.decode(subscription.topics)
        for _, subscribedTopic in ipairs(topics) do
          if subscribedTopic == topic then
            return true
          end
        end
        return false
      end
    end

    return newmodule
  end
end

local function newmodule(cfg)
  local isInitial = Subscribable == nil

  -- for bug-prevention, force the package user to be explicit on initial require
  assert(not isInitial or cfg and cfg.useDB ~= nil,
    "cfg.useDb is required: are you using the sqlite version (true) or the Lua-table based version (false)?")

  local pkg = Subscribable or
      { useDB = cfg.useDB } -- useDB can only be set on initialization; afterwards it remains the same

  pkg.version = '2.0.0'     -- requires an aos 2.0 process, uses msg.reply() etc.

  -- pkg acts like the package "global", bundling the state and API functions of the package

  if pkg.useDB then
    require "storage-db" (pkg)
  else
    require "storage-vanilla" (pkg)
  end

  require "pkg-api" (pkg)

  Handlers.add(
    "subscribable.Register-Subscriber",
    Handlers.utils.hasMatchingTag("Action", "Register-Subscriber"),
    pkg.handleRegisterSubscriber
  )

  Handlers.add(
    'subscribable.Get-Subscriber',
    Handlers.utils.hasMatchingTag('Action', 'Get-Subscriber'),
    pkg.handleGetSubscriber
  )

  Handlers.add(
    "subscribable.Receive-Payment",
    function(msg)
      return Handlers.utils.hasMatchingTag("Action", "Credit-Notice")(msg)
          and Handlers.utils.hasMatchingTag("X-Action", "Pay-For-Subscription")(msg)
    end,
    pkg.handleReceivePayment
  )

  Handlers.add(
    'subscribable.Subscribe-To-Topics',
    Handlers.utils.hasMatchingTag('Action', 'Subscribe-To-Topics'),
    pkg.handleSubscribeToTopics
  )

  Handlers.add(
    'subscribable.Unsubscribe-From-Topics',
    Handlers.utils.hasMatchingTag('Action', 'Unsubscribe-From-Topics'),
    pkg.handleUnsubscribeFromTopics
  )

  return pkg
end
return newmodule
end
end

do
local _ENV = _ENV
package.preload[ "utils.assertions" ] = function( ... ) local arg = _G.arg;
local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local assert = _tl_compat and _tl_compat.assert or assert; local pcall = _tl_compat and _tl_compat.pcall or pcall; local string = _tl_compat and _tl_compat.string or string; local bint = require("utils.tl-bint")(256)
local mod = {}





function mod.isBintRaw(val)
   local success, result = pcall(
   function()

      if type(val) ~= "number" and type(val) ~= "string" and not bint.isbint(val) then
         return false
      end


      if type(val) == "number" and (val ~= val or val % 1 ~= 0) then
         return false
      end

      return true
   end)


   return success and result
end





function mod.isTokenQuantity(qty)
   if type(qty) == "nil" then
      return false
   end
   if type(qty) == "number" and qty < 0 then
      return false
   end
   if type(qty) == "string" and string.sub(qty, 1, 1) == "-" then
      return false
   end
   if not mod.isBintRaw(qty) then return false end

   return true
end




function mod.isAddress(addr, prependMsg)
   local prepended = prependMsg and (prependMsg .. ": ") or ""

   assert(type(addr) == "string", prepended .. "Invalid type for Arweave address (must be string)")
   assert(addr:len() == 43, prepended .. "Invalid length for Arweave address")
   assert(addr:match("[A-z0-9_-]+"), prepended .. "Invalid characters in Arweave address")
   return true
end


function mod.checkIsAddress(addr)
   if type(addr) ~= "string" then return false, "Invalid type for Arweave address (must be string)" end
   if addr:len() ~= 43 then return false, "Invalid length for Arweave address" end
   if not addr:match("[A-z0-9_-]+") then return false, "Invalid characters in Arweave address" end
   return true
end





function mod.isSlippagePercentage(percentage)
   return type(percentage) == "number" and
   percentage > 0 and
   (percentage * 100) % 1 == 0 and
   percentage < 100
end

function mod.isFeeDiscountTier(tier)
   local isValid = tier == 'portfolio-agent'

   assert(isValid, 'Invalid Fee Discount Tier: ' .. tier)
end

return mod
end
end

do
local _ENV = _ENV
package.preload[ "utils.bintmath" ] = function( ... ) local arg = _G.arg;
local bint = require("utils.tl-bint")(256)
local bint_large = require("utils.tl-bint")(512)

local mod = {}





function mod.sqrt(x)

   if bint.eq(x, bint.zero()) then return bint.zero() end
   if bint.ule(x, bint(3)) then return bint.one() end


   local res = x
   local nextVal = bint.udiv(x, bint(2)) + bint.one()

   while bint.ult(nextVal, res) do
      res = nextVal
      nextVal = bint.udiv(bint.udiv(x, nextVal) + nextVal, bint(2))
   end

   return res
end

function mod.sqrt_large(x)

   if bint_large.eq(x, bint_large.zero()) then return bint_large.zero() end
   if bint_large.ule(x, bint_large(3)) then return bint_large.one() end


   local res = x
   local nextVal = bint_large.udiv(x, bint_large(2)) + bint_large.one()

   while bint_large.ult(nextVal, res) do
      res = nextVal
      nextVal = bint_large.udiv(bint_large.udiv(x, nextVal) + nextVal, bint_large(2))
   end

   return res
end

function mod.div_round_up(x, y)
   local quot, rem = bint.tdivmod(x, y)
   if not rem:iszero() and (bint.ispos(x) == bint.ispos(y)) then
      quot:_inc()
   end
   return quot
end

function mod.div_round_up_large(x, y)
   local quot, rem = bint_large.tdivmod(x, y)
   if not rem:iszero() and (bint_large.ispos(x) == bint_large.ispos(y)) then
      quot:_inc()
   end
   return quot
end


return mod
end
end

do
local _ENV = _ENV
package.preload[ "utils.output" ] = function( ... ) local arg = _G.arg;
local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local string = _tl_compat and _tl_compat.string or string; local mod = {}

function mod.formatAddress(addr, len)
   if not len then len = 3 end
   if not addr then return "unknown" end
   return Colors.green ..
   string.sub(addr, 1, len) ..
   "..." ..
   string.sub(addr, -len) ..
   Colors.reset
end

function mod.prefix(action, from)
   return Colors.gray ..
   "New " ..
   Colors.blue ..
   action ..
   Colors.gray ..
   " from " ..
   mod.formatAddress(from) ..
   Colors.gray ..
   ": " ..
   Colors.reset
end

return mod
end
end

do
local _ENV = _ENV
package.preload[ "utils.patterns" ] = function( ... ) local arg = _G.arg;
local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local debug = _tl_compat and _tl_compat.debug or debug; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local pcall = _tl_compat and _tl_compat.pcall or pcall; local string = _tl_compat and _tl_compat.string or string; local mod = {}

local json = require("json")
require("amm.pool.globals")










function mod.continue(fn)
   return function(msg)
      local patternResult = fn(msg)
      if not patternResult or patternResult == 0 or patternResult == "skip" then
         return 0
      end
      return 1
   end
end






function mod.hasMatchingTagOf(name, values)
   return function(msg)
      for _, value in ipairs(values) do
         local patternResult = Handlers.utils.hasMatchingTag(name, value)(msg)


         if patternResult ~= 0 and patternResult ~= false and patternResult ~= "skip" then
            return 1
         end
      end

      return 0
   end
end





function mod._and(patterns)
   return function(msg)
      for _, pattern in ipairs(patterns) do
         local patternResult = pattern(msg)

         if not patternResult or patternResult == 0 or patternResult == "skip" then
            return 0
         end
      end

      return -1
   end
end









function mod.catchWrapper(handler, handlerName)

   local nameString = handlerName and handlerName .. " - " or ""

   return function(msg, env)

      local status
      local result

      status, result = pcall(handler, msg, env)


      if not status then
         local traceback = debug.traceback()

         print("!!! Error: " .. nameString .. json.encode(traceback))
         local err = string.gsub(result, "%[[%w_.\" ]*%]:%d*: ", "")



         RefundError = err

         return nil
      end

      return result
   end
end







function mod.traceError(handler, handlerName)
   local nameString = handlerName and handlerName .. " - " or ""

   return function(msg, env)

      local status, result = pcall(handler, msg, env)
      if not status then
         local traceback = debug.traceback()

         local errorInfo = {
            message = "Error: " .. nameString .. tostring(traceback),
            originalError = result,
            handlerName = handlerName,
            messageType = type(msg),
            envType = type(env),

            messageContent = msg and json.encode(msg) or "nil",
            envContent = env and json.encode(env) or "nil",

            errorLine = traceback:match(":(%d+):"),

            specificError = traceback:match(":%d+:%s(.+)"),
         }
         print("Detailed error information:")

         error(json.encode(errorInfo))
         print(result)
      end
      return result
   end
end

return mod
end
end

do
local _ENV = _ENV
package.preload[ "utils.responses" ] = function( ... ) local arg = _G.arg;
local json = require("json")

local mod = {}

function mod.sendReply(msg, data, tags)
   msg.reply({
      Action = msg.Tags.Action .. "-Response",
      Tags = tags,
      Data = json.encode(data),
   })
end

function mod.sendConfirmation(msg, tags)
   msg.reply({
      Action = msg.Tags.Action .. "-Confirmation",
      Tags = tags,
      Status = "OK",
   })
end

function mod.sendProgressUpdate(msg, tags)
   ao.send({
      Target = msg.From,
      Action = msg.Tags.Action .. "-Progress",
      Tags = tags,
   })
end

function mod.sendError(msg, errorMessage, tags)
   ao.send({
      Target = msg.From,
      Action = msg.Tags.Action .. "-Error",
      Status = "Error",
      Tags = tags,
      Error = errorMessage,
   })
end

return mod
end
end

do
local _ENV = _ENV
package.preload[ "utils.tl-bint" ] = function( ... ) local arg = _G.arg;
local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local assert = _tl_compat and _tl_compat.assert or assert; local debug = _tl_compat and _tl_compat.debug or debug; local math = _tl_compat and _tl_compat.math or math; local _tl_math_maxinteger = math.maxinteger or math.pow(2, 53); local _tl_math_mininteger = math.mininteger or -math.pow(2, 53) - 1; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table; local _tl_table_unpack = unpack or table.unpack; BigInteger = {}































































































































































































































local function luainteger_bitsize()
   local n = -1
   local i = 0
   repeat
      n, i = n >> 16, i + 16
   until n == 0
   return i
end

local math_type = math.type
local math_floor = math.floor
local math_abs = math.abs
local math_ceil = math.ceil
local math_modf = math.modf
local math_mininteger = _tl_math_mininteger
local math_maxinteger = _tl_math_maxinteger
local math_max = math.max
local math_min = math.min
local string_format = string.format
local table_insert = table.insert
local table_concat = table.concat
local table_unpack = _tl_table_unpack

local memo = {}








local function newmodule(bits, wordbits)

   local intbits = luainteger_bitsize()
   bits = bits or 256
   wordbits = wordbits or (intbits // 2)


   local memoindex = bits * 64 + wordbits
   if memo[memoindex] then
      return memo[memoindex]
   end


   assert(bits % wordbits == 0, 'bitsize is not multiple of word bitsize')
   assert(2 * wordbits <= intbits, 'word bitsize must be half of the lua integer bitsize')
   assert(bits >= 64, 'bitsize must be >= 64')
   assert(wordbits >= 8, 'wordbits must be at least 8')
   assert(bits % 8 == 0, 'bitsize must be multiple of 8')


   local bint = {}
   bint.__index = bint


   bint.bits = bits


   local BINT_BITS = bits
   local BINT_BYTES = bits // 8
   local BINT_WORDBITS = wordbits
   local BINT_SIZE = BINT_BITS // BINT_WORDBITS
   local BINT_WORDMAX = (1 << BINT_WORDBITS) - 1
   local BINT_WORDMSB = (1 << (BINT_WORDBITS - 1))
   local BINT_LEPACKFMT = '<' .. ('I' .. (wordbits // 8)):rep(BINT_SIZE)
   local BINT_MATHMININTEGER
   local BINT_MATHMAXINTEGER
   local BINT_MININTEGER


   function bint.zero()
      local x = setmetatable({}, bint)
      for i = 1, BINT_SIZE do
         x[i] = 0
      end
      return x
   end
   local bint_zero = bint.zero


   function bint.one()
      local x = setmetatable({}, bint)
      x[1] = 1
      for i = 2, BINT_SIZE do
         x[i] = 0
      end
      return x
   end
   local bint_one = bint.one


   local function tointeger(x)
      x = tonumber(x)
      local ty = math_type(x)
      if ty == 'float' then
         local floorx = math_floor(x)
         if floorx == x then
            x = floorx
            ty = math_type(x)
         end
      end
      if ty == 'integer' then
         return x
      end
   end






   function bint.fromuinteger(x)
      x = tointeger(x)
      if x then
         if x == 1 then
            return bint_one()
         elseif x == 0 then
            return bint_zero()
         end
         local n = setmetatable({}, bint)
         for i = 1, BINT_SIZE do
            n[i] = x & BINT_WORDMAX
            x = x >> BINT_WORDBITS
         end
         return n
      end
   end
   local bint_fromuinteger = bint.fromuinteger





   function bint.frominteger(x)
      x = tointeger(x)
      if x then
         if x == 1 then
            return bint_one()
         elseif x == 0 then
            return bint_zero()
         end
         local neg = false
         if x < 0 then
            x = math_abs(x)
            neg = true
         end
         local n = setmetatable({}, bint)
         for i = 1, BINT_SIZE do
            n[i] = x & BINT_WORDMAX
            x = x >> BINT_WORDBITS
         end
         if neg then
            n:_unm()
         end
         return n
      end
   end
   local bint_frominteger = bint.frominteger


   local basesteps = {}


   local function getbasestep(base)
      local step = basesteps[base]
      if step then
         return step
      end
      step = 0
      local dmax = 1
      local limit = math_maxinteger // base
      repeat
         step = step + 1
         dmax = dmax * base
      until dmax >= limit
      basesteps[base] = step
      return step
   end


   local function ipow(y, x, n)
      if n == 1 then
         return y * x
      elseif n & 1 == 0 then
         return ipow(y, x * x, n // 2)
      end
      return ipow(x * y, x * x, (n - 1) // 2)
   end






   function bint.isbint(x)




      local isTable = type(x) == 'table'
      local mt = getmetatable(x)

      local isBintish = mt and mt.isbint and
      mt.tobint and
      mt.zero and
      mt.iszero and
      mt.frombase and
      mt.tobase and
      mt.isneg and
      mt.ispos and
      true

      return isTable and isBintish
   end


   local function bint_assert_convert(x)
      if not bint.isbint(x) then
         print(debug.traceback())
         assert(bint.isbint(x), 'bint_assert_convert: expected BigInteger, got ' .. type(x) .. ' value ' .. tostring(x))
      end
      return x
   end


   local function bint_assert_convert_clone(x)
      if not bint.isbint(x) then
         print(debug.traceback())
         assert(bint.isbint(x), 'bint_assert_convert_clone: expected BigInteger, got ' .. type(x) .. ' value ' .. tostring(x))
      end
      local n = setmetatable({}, bint)
      local xi = x
      for i = 1, BINT_SIZE do
         n[i] = xi[i]
      end
      return n
   end


   local function bint_assert_convert_from_integer(x)
      local xi = bint_frominteger(x)
      assert(xi, 'bint_assert_convert_from_integer: could not convert integer to big integer' .. type(x) .. ' value ' .. tostring(x))
      return xi
   end







   function bint.frombase(s, base)
      if type(s) ~= 'string' then
         error('s is not a string')
      end
      base = base or 10
      if not (base >= 2 and base <= 36) then
         error('number base is too large')
      end
      local step = getbasestep(base)
      if #s < step then

         return bint_frominteger(tonumber(s, base))
      end
      local sign
      local int
      sign, int = s:lower():match('^([+-]?)(%w+)$')
      if not (sign and int) then
         error('invalid integer string representation')
      end
      local n = bint_zero()
      for i = 1, #int, step do
         local part = int:sub(i, i + step - 1)
         local d = tonumber(part, base)
         if not d then
            error('invalid integer string representation')
         end
         if i > 1 then
            n = n * bint_frominteger(ipow(1, base, #part))
         end
         if d ~= 0 then
            n:_add(bint_frominteger(d))
         end
      end
      if sign == '-' then
         n:_unm()
      end
      return n
   end
   local bint_frombase = bint.frombase






   function bint.fromstring(s)
      if type(s) ~= 'string' then
         error('s is not a string')
      end
      if s:find('^[+-]?[0-9]+$') then
         return bint_frombase(s, 10)
      elseif s:find('^[+-]?0[xX][0-9a-fA-F]+$') then
         return bint_frombase(s:gsub('0[xX]', '', 1), 16)
      elseif s:find('^[+-]?0[bB][01]+$') then
         return bint_frombase(s:gsub('0[bB]', '', 1), 2)
      end
   end
   local bint_fromstring = bint.fromstring





   function bint.fromle(buffer)
      assert(type(buffer) == 'string', 'buffer is not a string')
      if #buffer > BINT_BYTES then
         buffer = buffer:sub(1, BINT_BYTES)
      elseif #buffer < BINT_BYTES then
         buffer = buffer .. ('\x00'):rep(BINT_BYTES - #buffer)
      end
      return setmetatable({ BINT_LEPACKFMT:unpack(buffer) }, bint)
   end





   function bint.frombe(buffer)
      assert(type(buffer) == 'string', 'buffer is not a string')
      if #buffer > BINT_BYTES then
         buffer = buffer:sub(-BINT_BYTES, #buffer)
      elseif #buffer < BINT_BYTES then
         buffer = ('\x00'):rep(BINT_BYTES - #buffer) .. buffer
      end
      return setmetatable({ BINT_LEPACKFMT:unpack(buffer:reverse()) }, bint)
   end






   function bint.new(x)
      if getmetatable(x) ~= bint then
         local ty = type(x)
         if ty == 'number' then
            x = bint_frominteger(x)
            assert(x, 'value cannot be represented by a bint')
            return x
         elseif ty == 'string' then
            x = bint_fromstring(x)
            assert(x, 'value cannot be represented by a bint')
            return x
         end
      end

      return bint_assert_convert_clone(x)
   end
   local bint_new = bint.new








   function bint.tobint(x, clone)
      if getmetatable(x) == bint then
         if not clone then
            return bint_assert_convert(x)
         end

         return bint_assert_convert_clone(x)
      end
      local ty = type(x)
      if ty == 'number' then
         return bint_frominteger(x)
      elseif ty == 'string' then
         return bint_fromstring(x)
      end
   end
   local tobint = bint.tobint

   function bint.touinteger(x)
      if getmetatable(x) == bint then
         local n = 0
         local xi = bint_assert_convert_clone(x)
         for i = 1, BINT_SIZE do
            n = n | (xi[i] << (BINT_WORDBITS * (i - 1)))
         end
         return n
      end
      return tointeger(x)
   end









   function bint.tointeger(x)
      if getmetatable(x) == bint then
         local xi = bint_assert_convert_clone(x)
         local n = 0
         for i = 1, BINT_SIZE do
            n = n | (xi[i] << (BINT_WORDBITS * (i - 1)))
         end
         return n
      end
      return tointeger(x)
   end

   local bint_tointeger = bint.tointeger

   local function bint_assert_tointeger(x)
      local xi = bint_tointeger(x)
      if not xi then
         error('bint_assert_tointeger: cannot convert to integer, got ' .. type(x) .. ' value ' .. tostring(x))
      end
      return xi
   end







   function bint.tonumber(x)
      x = bint_assert_convert_clone(x)
      if x:le(BINT_MATHMAXINTEGER) and x:ge(BINT_MATHMININTEGER) then
         return x:tointeger()
      end
      print('warning: too big for int, casting to number, potential precision loss')
      return tonumber(x)
   end
   local bint_tonumber = bint.tonumber


   local BASE_LETTERS = {}
   do
      for i = 1, 36 do
         BASE_LETTERS[i - 1] = ('0123456789abcdefghijklmnopqrstuvwxyz'):sub(i, i)
      end
   end










   function bint.tobase(x, base, unsigned)
      x = bint_assert_convert_clone(x)
      if not x then
         error('x is a fractional float or something else')
      end
      base = base or 10
      if not (base >= 2 and base <= 36) then

         return
      end
      if unsigned == nil then
         unsigned = base ~= 10
      end
      local isxneg = x:isneg()
      if (base == 10 and not unsigned) or (base == 16 and unsigned and not isxneg) then
         if x:le(BINT_MATHMAXINTEGER) and x:ge(BINT_MATHMININTEGER) then

            local n = x:tointeger()
            if base == 10 then
               return tostring(n)
            elseif unsigned then
               return string_format('%x', n)
            end
         end
      end
      local ss = {}
      local neg = not unsigned and isxneg
      x = neg and x:abs() or bint_new(x)
      local xiszero = x:iszero()
      if xiszero then
         return '0'
      end

      local step = 0
      local basepow = 1
      local limit = (BINT_WORDMSB - 1) // base
      repeat
         step = step + 1
         basepow = basepow * base
      until basepow >= limit

      local size = BINT_SIZE
      local xd
      local carry
      local d
      repeat

         carry = 0
         xiszero = true
         for i = size, 1, -1 do
            carry = carry | x[i]
            d, xd = carry // basepow, carry % basepow
            if xiszero and d ~= 0 then
               size = i
               xiszero = false
            end
            x[i] = d
            carry = xd << BINT_WORDBITS
         end

         for _ = 1, step do
            xd, d = xd // base, xd % base
            if xiszero and xd == 0 and d == 0 then

               break
            end
            table_insert(ss, 1, BASE_LETTERS[d])
         end
      until xiszero
      if neg then
         table_insert(ss, 1, '-')
      end
      return table_concat(ss)
   end








   function bint.tole(x, trim)
      x = bint_assert_convert_clone(x)
      local s = BINT_LEPACKFMT:pack(table_unpack(x))
      if trim then
         s = s:gsub('\x00+$', '')
         if s == '' then
            s = '\x00'
         end
      end
      return s
   end






   function bint.tobe(x, trim)
      x = bint_assert_convert_clone(x)
      local xt = { table_unpack(x) }
      local s = BINT_LEPACKFMT:pack(table_unpack(xt)):reverse()
      if trim then
         s = s:gsub('^\x00+', '')
         if s == '' then
            s = '\x00'
         end
      end
      return s
   end



   function bint.iszero(x)
      local xi = bint_assert_convert(x)
      for i = 1, BINT_SIZE do
         if xi[i] ~= 0 then
            return false
         end
      end
      return true
   end



   function bint.isone(x)
      local xi = bint_assert_convert(x)
      if xi[1] ~= 1 then
         return false
      end
      for i = 2, BINT_SIZE do
         if xi[i] ~= 0 then
            return false
         end
      end
      return true
   end



   function bint.isminusone(x)
      local xi = bint_assert_convert(x)
      if xi[1] ~= BINT_WORDMAX then
         return false
      end
      return true
   end
   local bint_isminusone = bint.isminusone



   function bint.isintegral(x)
      return getmetatable(x) == bint or math_type(x) == 'integer'
   end



   function bint.isnumeric(x)
      return getmetatable(x) == bint or type(x) == 'number'
   end





   function bint.type(x)
      if getmetatable(x) == bint then
         return 'bint'
      end
      return math_type(x)
   end




   function bint.isneg(x)
      bint_assert_convert(x)
      return x[BINT_SIZE] & BINT_WORDMSB ~= 0
   end
   local bint_isneg = bint.isneg



   function bint.ispos(x)
      bint_assert_convert(x)
      return not x:isneg() and not x:iszero()
   end



   function bint.iseven(x)
      bint_assert_convert(x)
      return x[1] & 1 == 0
   end



   function bint.isodd(x)
      bint_assert_convert(x)
      return x[1] & 1 == 1
   end


   function bint.maxinteger()
      local x = setmetatable({}, bint)
      for i = 1, BINT_SIZE - 1 do
         x[i] = BINT_WORDMAX
      end
      x[BINT_SIZE] = BINT_WORDMAX ~ BINT_WORDMSB
      return x
   end


   function bint.mininteger()
      local x = setmetatable({}, bint)
      for i = 1, BINT_SIZE - 1 do
         x[i] = 0
      end
      x[BINT_SIZE] = BINT_WORDMSB
      return x
   end


   function bint:_shlone()
      local wordbitsm1 = BINT_WORDBITS - 1
      for i = BINT_SIZE, 2, -1 do
         self[i] = ((self[i] << 1) | (self[i - 1] >> wordbitsm1)) & BINT_WORDMAX
      end
      self[1] = (self[1] << 1) & BINT_WORDMAX
      return self
   end


   function bint:_shrone()
      local wordbitsm1 = BINT_WORDBITS - 1
      for i = 1, BINT_SIZE - 1 do
         self[i] = ((self[i] >> 1) | (self[i + 1] << wordbitsm1)) & BINT_WORDMAX
      end
      self[BINT_SIZE] = self[BINT_SIZE] >> 1
      return self
   end


   function bint:_shlwords(n)
      for i = BINT_SIZE, n + 1, -1 do
         self[i] = self[i - n]
      end
      for i = 1, n do
         self[i] = 0
      end
      return self
   end


   function bint:_shrwords(n)
      if n < BINT_SIZE then
         for i = 1, BINT_SIZE - n do
            self[i] = self[i + n]
         end
         for i = BINT_SIZE - n + 1, BINT_SIZE do
            self[i] = 0
         end
      else
         for i = 1, BINT_SIZE do
            self[i] = 0
         end
      end
      return self
   end


   function bint:_inc()
      for i = 1, BINT_SIZE do
         local tmp = self[i]
         local v = (tmp + 1) & BINT_WORDMAX
         self[i] = v
         if v > tmp then
            break
         end
      end
      return self
   end



   function bint.inc(x)
      local ix = bint_assert_convert(x)
      return ix:_inc()
   end


   function bint:_dec()
      for i = 1, BINT_SIZE do
         local tmp = self[i]
         local v = (tmp - 1) & BINT_WORDMAX
         self[i] = v
         if v <= tmp then
            break
         end
      end
      return self
   end



   function bint.dec(x)
      local ix = bint_assert_convert(x)
      return ix:_dec()
   end




   function bint:_assign(y)
      y = bint_assert_convert(y)
      for i = 1, BINT_SIZE do
         self[i] = y[i]
      end
      return self
   end


   function bint:_abs()
      if self:isneg() then
         self:_unm()
      end
      return self
   end



   function bint.abs(x)
      local ix = bint_assert_convert_clone(x)
      return ix:_abs()
   end
   local bint_abs = bint.abs



   function bint.floor(x)
      return bint_assert_convert_clone(x)
   end



   function bint.ceil(x)
      return bint_assert_convert_clone(x)
   end




   function bint.bwrap(x, y)
      x = bint_assert_convert(x)
      if y <= 0 then
         return bint_zero()
      elseif y < BINT_BITS then
         local tmp = (bint_one() << y)
         local tmp2 = tmp:_dec():tointeger()
         return x & tmp2
      end
      return bint_new(x)
   end




   function bint.brol(x, y)
      x, y = bint_assert_convert(x), bint_assert_tointeger(y)
      if y > 0 then
         return (x << y) | (x >> (BINT_BITS - y))
      elseif y < 0 then
         if y ~= math_mininteger then
            return x:bror(-y)
         else
            x:bror(-(y + 1))
            x:bror(1)
         end
      end
      return x
   end




   function bint.bror(x, y)
      x, y = bint_assert_convert(x), bint_assert_tointeger(y)
      if y > 0 then
         return (x >> y) | (x << (BINT_BITS - y))
      elseif y < 0 then
         if y ~= math_mininteger then
            return x:brol(-y)
         else
            x:brol(-(y + 1))
            x:brol(1)
         end
      end
      return x
   end





   function bint.max(x, y)
      local ix = bint_assert_convert(x)
      local iy = bint_assert_convert(y)
      return bint_new(ix:gt(iy) and ix or iy)
   end





   function bint.min(x, y)
      local ix = bint_assert_convert(x)
      local iy = bint_assert_convert(y)
      return bint_new(ix:lt(iy) and ix or iy)
   end




   function bint:_add(y)
      y = bint_assert_convert(y)
      local carry = 0
      for i = 1, BINT_SIZE do
         local tmp = self[i] + y[i] + carry
         carry = tmp >> BINT_WORDBITS
         self[i] = tmp & BINT_WORDMAX
      end
      return self
   end




   function bint.__add(x, y)
      local ix = bint_assert_convert(x)
      local iy = bint_assert_convert(y)
      local z = setmetatable({}, bint)
      local carry = 0
      for i = 1, BINT_SIZE do
         local tmp = ix[i] + iy[i] + carry
         carry = tmp >> BINT_WORDBITS
         z[i] = tmp & BINT_WORDMAX
      end
      return z
   end




   function bint:_sub(y)
      y = bint_assert_convert(y)
      local borrow = 0
      local wordmaxp1 = BINT_WORDMAX + 1
      for i = 1, BINT_SIZE do
         local res = self[i] + wordmaxp1 - y[i] - borrow
         self[i] = res & BINT_WORDMAX
         borrow = (res >> BINT_WORDBITS) ~ 1
      end
      return self
   end




   function bint.__sub(x, y)
      local ix = bint_assert_convert(x)
      local iy = bint_assert_convert(y)
      local z = setmetatable({}, bint)
      local borrow = 0
      local wordmaxp1 = BINT_WORDMAX + 1
      for i = 1, BINT_SIZE do
         local res = ix[i] + wordmaxp1 - iy[i] - borrow
         z[i] = res & BINT_WORDMAX
         borrow = (res >> BINT_WORDBITS) ~ 1
      end
      return z
   end




   function bint.__mul(x, y)
      local ix = bint_assert_convert(x)
      local iy = bint_assert_convert(y)
      local z = bint_zero()
      local sizep1 = BINT_SIZE + 1
      local s = sizep1
      local e = 0
      for i = 1, BINT_SIZE do
         if ix[i] ~= 0 or iy[i] ~= 0 then
            e = math_max(e, i)
            s = math_min(s, i)
         end
      end
      for i = s, e do
         for j = s, math_min(sizep1 - i, e) do
            local a = ix[i] * iy[j]
            if a ~= 0 then
               local carry = 0
               for k = i + j - 1, BINT_SIZE do
                  local tmp = z[k] + (a & BINT_WORDMAX) + carry
                  carry = tmp >> BINT_WORDBITS
                  z[k] = tmp & BINT_WORDMAX
                  a = a >> BINT_WORDBITS
               end
            end
         end
      end
      return z
   end




   function bint.__eq(x, y)
      bint_assert_convert(x)
      bint_assert_convert(y)
      for i = 1, BINT_SIZE do
         if x[i] ~= y[i] then
            return false
         end
      end
      return true
   end




   function bint.eq(x, y)
      local ix = bint_assert_convert(x)
      local iy = bint_assert_convert(y)
      return ix == iy
   end
   local bint_eq = bint.eq

   local function findleftbit(x)
      for i = BINT_SIZE, 1, -1 do
         local v = x[i]
         if v ~= 0 then
            local j = 0
            repeat
               v = v >> 1
               j = j + 1
            until v == 0
            return (i - 1) * BINT_WORDBITS + j - 1, i
         end
      end
   end


   local function sudivmod(nume, deno)
      local rema
      local carry = 0
      for i = BINT_SIZE, 1, -1 do
         carry = carry | nume[i]
         nume[i] = carry // deno
         rema = carry % deno
         carry = rema << BINT_WORDBITS
      end
      return rema
   end










   function bint.udivmod(x, y)
      local nume = bint_assert_convert_clone(x)
      local deno = bint_assert_convert(y)

      local ishighzero = true
      for i = 2, BINT_SIZE do
         if deno[i] ~= 0 then
            ishighzero = false
            break
         end
      end
      if ishighzero then

         local low = deno[1]
         assert(low ~= 0, 'attempt to divide by zero')
         if low == 1 then

            return nume, bint_zero()
         elseif low <= (BINT_WORDMSB - 1) then

            local rema = sudivmod(nume, low)
            return nume, bint_fromuinteger(rema)
         end
      end
      if nume:ult(deno) then

         return bint_zero(), nume
      end

      local denolbit = findleftbit(deno)
      local numelbit, numesize = findleftbit(nume)
      local bit = numelbit - denolbit
      deno = deno << bit
      local wordmaxp1 = BINT_WORDMAX + 1
      local wordbitsm1 = BINT_WORDBITS - 1
      local denosize = numesize
      local quot = bint_zero()
      while bit >= 0 do

         local le = true
         local size = math_max(numesize, denosize)
         for i = size, 1, -1 do
            local a, b = deno[i], nume[i]
            if a ~= b then
               le = a < b
               break
            end
         end

         if le then

            local borrow = 0
            for i = 1, size do
               local res = nume[i] + wordmaxp1 - deno[i] - borrow
               nume[i] = res & BINT_WORDMAX
               borrow = (res >> BINT_WORDBITS) ~ 1
            end

            local i = (bit // BINT_WORDBITS) + 1
            quot[i] = quot[i] | (1 << (bit % BINT_WORDBITS))
         end

         for i = 1, denosize - 1 do
            deno[i] = ((deno[i] >> 1) | (deno[i + 1] << wordbitsm1)) & BINT_WORDMAX
         end
         local lastdenoword = deno[denosize] >> 1
         deno[denosize] = lastdenoword

         if lastdenoword == 0 then
            while deno[denosize] == 0 do
               denosize = denosize - 1
            end
            if denosize == 0 then
               break
            end
         end

         bit = bit - 1
      end

      return quot, nume
   end
   local bint_udivmod = bint.udivmod







   function bint.udiv(x, y)
      bint_assert_convert(x)
      bint_assert_convert(y)
      return (bint_udivmod(x, y))
   end







   function bint.umod(x, y)
      bint_assert_convert(x)
      bint_assert_convert(y)
      local _, rema = bint_udivmod(x, y)
      return rema
   end
   local bint_umod = bint.umod









   function bint.tdivmod(x, y)
      bint_assert_convert(x)
      bint_assert_convert(y)
      local ax
      local ay
      ax, ay = bint_abs(x), bint_abs(y)

      local ix
      local iy
      ix, iy = tobint(ax), tobint(ay)
      local quot
      local rema
      if ix and iy then
         assert(not (bint_eq(x, BINT_MININTEGER) and bint_isminusone(y)), 'division overflow')
         quot, rema = bint_udivmod(ix, iy)
      else
         quot, rema = ax // ay, ax % ay
      end
      local isxneg
      local isyneg
      isxneg, isyneg = bint_isneg(x), bint_isneg(y)

      if isxneg ~= isyneg then
         quot = -quot
      end
      if isxneg then
         rema = -rema
      end
      return quot, rema
   end
   local bint_tdivmod = bint.tdivmod







   function bint.tdiv(x, y)
      bint_assert_convert(x)
      bint_assert_convert(y)
      return (bint_tdivmod(x, y))
   end








   function bint.tmod(x, y)
      local _, rema = bint_tdivmod(x, y)
      return rema
   end










   function bint.idivmod(x, y)
      local ix = bint_assert_convert(x)
      local iy = bint_assert_convert(y)
      local isnumeneg = ix[BINT_SIZE] & BINT_WORDMSB ~= 0
      local isdenoneg = iy[BINT_SIZE] & BINT_WORDMSB ~= 0
      if isnumeneg then
         ix = -ix
      end
      if isdenoneg then
         iy = -iy
      end
      local quot
      local rema
      quot, rema = bint_udivmod(ix, iy)
      if isnumeneg ~= isdenoneg then
         quot:_unm()

         if not rema:iszero() then
            quot:_dec()

            if isnumeneg and not isdenoneg then
               rema:_unm():_add(y)
            elseif isdenoneg and not isnumeneg then
               rema:_add(y)
            end
         end
      elseif isnumeneg then

         rema:_unm()
      end
      return quot, rema
   end
   local bint_idivmod = bint.idivmod








   function bint.__idiv(x, y)
      local ix = bint_assert_convert(x)
      local iy = bint_assert_convert(y)
      local isnumeneg = ix[BINT_SIZE] & BINT_WORDMSB ~= 0
      local isdenoneg = iy[BINT_SIZE] & BINT_WORDMSB ~= 0
      if isnumeneg then
         ix = -ix
      end
      if isdenoneg then
         iy = -iy
      end
      local quot
      local rema
      quot, rema = bint_udivmod(ix, iy)
      if isnumeneg ~= isdenoneg then
         quot:_unm()

         if not rema:iszero() then
            quot:_dec()
         end
      end
      return quot, rema
   end









   function bint.__mod(x, y)
      local _, rema = bint_idivmod(x, y)
      return rema
   end









   function bint.ipow(x, y)
      local ix = bint_assert_convert(x)
      local iy = bint_assert_convert(y)
      if iy:iszero() then
         return bint_one()
      elseif iy:isone() then
         return bint_new(ix)
      end

      x, y = bint_new(x), bint_new(y)
      local z = bint_one()
      repeat
         if y:iseven() then
            x = x * x
            y:_shrone()
         else
            z = x * z
            x = x * x
            y:_dec():_shrone()
         end
      until y:isone()
      return x * z
   end









   function bint.upowmod(x, y, m)
      local mi = bint_assert_convert(m)
      if mi:isone() then
         return bint_zero()
      end
      local xi = bint_new(x)
      local yi = bint_new(y)
      local z = bint_one()
      xi = bint_umod(xi, mi)
      while not yi:iszero() do
         if yi:isodd() then
            z = bint_umod(z * xi, mi)
         end
         yi:_shrone()
         xi = bint_umod(xi * xi, mi)
      end
      return z
   end







   function bint.__shl(x, y)
      x, y = bint_assert_convert_clone(x), bint_assert_tointeger(y)
      if y == math_mininteger or math_abs(y) >= BINT_BITS then
         return bint_zero()
      end
      if y < 0 then
         return x >> -y
      end
      local nvals = y // BINT_WORDBITS
      if nvals ~= 0 then
         x:_shlwords(nvals)
         y = y - nvals * BINT_WORDBITS
      end
      if y ~= 0 then
         local wordbitsmy = BINT_WORDBITS - y
         for i = BINT_SIZE, 2, -1 do
            x[i] = ((x[i] << y) | (x[i - 1] >> wordbitsmy)) & BINT_WORDMAX
         end
         x[1] = (x[1] << y) & BINT_WORDMAX
      end
      return x
   end






   function bint.__shr(x, y)
      x, y = bint_assert_convert_clone(x), bint_assert_tointeger(y)
      if y == math_mininteger or math_abs(y) >= BINT_BITS then
         return bint_zero()
      end
      if y < 0 then
         return x << -y
      end
      local nvals = y // BINT_WORDBITS
      if nvals ~= 0 then
         x:_shrwords(nvals)
         y = y - nvals * BINT_WORDBITS
      end
      if y ~= 0 then
         local wordbitsmy = BINT_WORDBITS - y
         for i = 1, BINT_SIZE - 1 do
            x[i] = ((x[i] >> y) | (x[i + 1] << wordbitsmy)) & BINT_WORDMAX
         end
         x[BINT_SIZE] = x[BINT_SIZE] >> y
      end
      return x
   end




   function bint:_band(y)
      local yi = bint_assert_convert_from_integer(y)
      for i = 1, BINT_SIZE do
         self[i] = self[i] & yi[i]
      end
      return self
   end





   function bint.__band(x, y)
      return bint_assert_convert_clone(x):_band(y)
   end




   function bint:_bor(y)
      y = bint_assert_convert(y)
      for i = 1, BINT_SIZE do
         self[i] = self[i] | y[i]
      end
      return self
   end





   function bint.__bor(x, y)
      return bint_assert_convert_clone(x):_bor(y)
   end




   function bint:_bxor(y)
      y = bint_assert_convert(y)
      for i = 1, BINT_SIZE do
         self[i] = self[i] ~ y[i]
      end
      return self
   end





   function bint.__bxor(x, y)
      return bint_assert_convert_clone(x):_bxor(y)
   end


   function bint:_bnot()
      for i = 1, BINT_SIZE do
         self[i] = (~self[i]) & BINT_WORDMAX
      end
      return self
   end

   function bint.__bnot(x)
      local y = setmetatable({}, bint)
      for i = 1, BINT_SIZE do
         y[i] = (~x[i]) & BINT_WORDMAX
      end
      return y
   end


   function bint:_unm()
      return self:_bnot():_inc()
   end



   function bint.__unm(x)
      return (~x):_inc()
   end






   function bint.ult(x, y)
      for i = BINT_SIZE, 1, -1 do
         local a = x[i]
         local b = y[i]
         if a ~= b then
            return a < b
         end
      end
      return false
   end






   function bint.ule(x, y)
      x, y = bint_assert_convert(x), bint_assert_convert(y)
      for i = BINT_SIZE, 1, -1 do
         local a = x[i]
         local b = y[i]
         if a ~= b then
            return a < b
         end
      end
      return true
   end





   function bint.lt(x, y)
      local ix = bint_assert_convert(x)
      local iy = bint_assert_convert(y)

      local xneg = ix[BINT_SIZE] & BINT_WORDMSB ~= 0
      local yneg = iy[BINT_SIZE] & BINT_WORDMSB ~= 0
      if xneg == yneg then
         for i = BINT_SIZE, 1, -1 do
            local a = ix[i]
            local b = iy[i]
            if a ~= b then
               return a < b
            end
         end
         return false
      end
      return xneg and not yneg
   end

   function bint:gt(y)
      return not self:eq(y) and not self:lt(y)
   end





   function bint.le(x, y)
      local ix = bint_assert_convert(x)
      local iy = bint_assert_convert(y)
      local xneg = ix[BINT_SIZE] & BINT_WORDMSB ~= 0
      local yneg = iy[BINT_SIZE] & BINT_WORDMSB ~= 0
      if xneg == yneg then
         for i = BINT_SIZE, 1, -1 do
            local a = ix[i]
            local b = iy[i]
            if a ~= b then
               return a < b
            end
         end
         return true
      end
      return xneg and not yneg
   end

   function bint:ge(y)
      return self:eq(y) or self:gt(y)
   end



   function bint:__tostring()
      return self:tobase(10)
   end


   setmetatable(bint, {
      __call = function(_, x)
         return bint_new(x)
      end,
   })

   BINT_MATHMININTEGER, BINT_MATHMAXINTEGER = bint_new(_tl_math_mininteger), bint_new(_tl_math_maxinteger)
   BINT_MININTEGER = bint.mininteger()
   memo[memoindex] = bint

   return bint

end

return newmodule
end
end

do
local _ENV = _ENV
package.preload[ "utils.tl-utils" ] = function( ... ) local arg = _G.arg;
local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local pairs = _tl_compat and _tl_compat.pairs or pairs; local table = _tl_compat and _tl_compat.table or table





local function find(predicate, arr)
   for _, value in ipairs(arr) do
      if predicate(value) then
         return value
      end
   end
   return nil
end

local function filter(predicate, arr)
   local result = {}
   for _, value in ipairs(arr) do
      if predicate(value) then
         table.insert(result, value)
      end
   end
   return result
end

local function reduce(reducer, initialValue, arr)
   local result = initialValue
   for i, value in ipairs(arr) do
      result = reducer(result, value, i, arr)
   end
   return result
end


local function map(mapper, arr)
   local result = {}
   for i, value in ipairs(arr) do
      result[i] = mapper(value, i, arr)
   end
   return result
end

local function reverse(arr)
   local result = {}
   for i = #arr, 1, -1 do
      table.insert(result, arr[i])
   end
   return result
end

local function compose(...)
   local funcs = { ... }
   return function(x)
      for i = #funcs, 1, -1 do
         x = funcs[i](x)
      end
      return x
   end
end

local function keys(xs)
   local ks = {}
   for k, _ in pairs(xs) do
      table.insert(ks, k)
   end
   return ks
end

local function values(xs)
   local vs = {}
   for _, v in pairs(xs) do
      table.insert(vs, v)
   end
   return vs
end

local function includes(value, arr)
   for _, v in ipairs(arr) do
      if v == value then
         return true
      end
   end
   return false
end

return {
   find = find,
   filter = filter,
   reduce = reduce,
   map = map,
   reverse = reverse,
   compose = compose,
   values = values,
   keys = keys,
   includes = includes,
}
end
end

local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local assert = _tl_compat and _tl_compat.assert or assert; local ammHandlers = require("amm.amm-handlers")
local incoming = require("amm.token.credit_notice")
local patterns = require("utils.patterns")
local transfer = require("amm.token.transfer")
local balance = require("amm.token.balance")
local outputs = require("utils.output")
local provide = require("amm.pool.provide")
local refund = require("amm.pool.refund")
local cancel = require("amm.pool.cancel")
local token = require("amm.token.token")
local burn = require("amm.pool.burn")
local pool = require("amm.pool.pool")
local swap = require("amm.pool.swap")
local utils = require("utils.tl-utils")
local json = require("json")
local responses = require("utils.responses")
local assertions = require("utils.assertions")


DexiTokenProcess = DexiTokenProcess or ao.env.Process.Tags['Dexi-Token']

assert(DexiTokenProcess, "DexiTokenProcess is not set")


token.init()
pool.init()





Handlers.add(
"info",
Handlers.utils.hasMatchingTag("Action", "Info"),
ammHandlers.handleGetInfo)


Handlers.add(
"Set-Fee-Collector",
Handlers.utils.hasMatchingTag("Action", "Set-Fee-Collector"),
function(msg)
   assert(msg.From == Owner or msg.From == ao.id, "Only the owner or self can set the fee collector")
   FeeCollector = msg.Tags["Fee-Collector"]
   responses.sendConfirmation(msg, { ["Fee-Collector"] = FeeCollector })
end)


Handlers.add(
"balance",
Handlers.utils.hasMatchingTag("Action", "Balance"),
balance.balance)

Handlers.add(
"balances",
Handlers.utils.hasMatchingTag("Action", "Balances"),
balance.balances)

Handlers.add(
"totalSupply",
Handlers.utils.hasMatchingTag("Action", "Total-Supply"),
function(msg)
   local res = balance.totalSupply()

   local replyData = tostring(res)
   local replyTags = { ["Total-Supply"] = tostring(res), Ticker = Ticker }
   responses.sendReply(msg, replyData, replyTags)

   print(
   outputs.prefix("Total-Supply", msg.From) ..
   Colors.gray ..
   "Total-Supply = " ..
   Colors.blue ..
   tostring(res) ..
   Colors.reset)

end)


Handlers.add(
"transfer",
Handlers.utils.hasMatchingTag("Action", "Transfer"),
transfer.transfer)


Handlers.add(
"getPair",
Handlers.utils.hasMatchingTag("Action", "Get-Pair"),
function(msg)
   local res = pool.getPair()

   local replyData = nil
   local replyTags = {
      ["Token-A"] = res[1],
      ["Token-B"] = res[2],
   }
   responses.sendReply(msg, replyData, replyTags)
   print(
   outputs.prefix("Get-Pair", msg.From) ..
   Colors.gray ..
   "Pair = " ..
   outputs.formatAddress(res[1]) ..
   Colors.gray ..
   "/" ..
   outputs.formatAddress(res[2]) ..
   Colors.reset)

end)

Handlers.add(
"getReserves",
Handlers.utils.hasMatchingTag("Action", "Get-Reserves"),
function(msg)
   local res = pool.getReserves()
   local pair = pool.getPair()

   local replyData = nil
   local replyTags = {
      [pair[1]] = tostring(res[pair[1]]),
      [pair[2]] = tostring(res[pair[2]]),
   }
   responses.sendReply(msg, replyData, replyTags)
   print(
   outputs.prefix("Get-Reserves", msg.From) ..
   Colors.gray ..
   "Reserves = [" ..
   outputs.formatAddress(pair[1]) ..
   Colors.gray ..
   "=" ..
   Colors.blue ..
   tostring(res[pair[1]]) ..
   Colors.gray ..
   ", " ..
   outputs.formatAddress(pair[2]) ..
   Colors.gray ..
   "=" ..
   Colors.blue ..
   tostring(res[pair[2]]) ..
   Colors.gray ..
   "]" ..
   Colors.reset)

end)

Handlers.add(
"K",
Handlers.utils.hasMatchingTag("Action", "Get-K"),
function(msg)
   local res = pool.K()

   local replyData = nil
   local replyTags = { ["K"] = tostring(res) }
   responses.sendReply(msg, replyData, replyTags)

   print(
   outputs.prefix("Get-K", msg.From) ..
   Colors.gray ..
   "K = " ..
   Colors.blue ..
   tostring(res) ..
   Colors.reset)

end)

Handlers.add(
"getPrice",
Handlers.utils.hasMatchingTag("Action", "Get-Price"),
pool.getPrice)


Handlers.add(
"getSwapOutput",
Handlers.utils.hasMatchingTag("Action", "Get-Swap-Output"),
pool.getSwapOutput)


Handlers.add(
"getFeePercentage",
Handlers.utils.hasMatchingTag("Action", "Get-Fee-Percentage"),
function(msg)
   local feeDiscountTier = msg.Tags["Fee-Discount-Tier"]
   if feeDiscountTier then
      assertions.isFeeDiscountTier(feeDiscountTier)
   end
   local replyData = nil
   local replyTags = pool.getFeesAsPercentages(feeDiscountTier)
   responses.sendReply(msg, replyData, replyTags)
end)


Handlers.add(
"getPendingProvides",
Handlers.utils.hasMatchingTag("Action", "Get-Pending-Provides"),
function(msg)
   local res = provide.findPendingProvide(msg.From)
   local replyData = nil
   local replyTags
   if (res) then
      res = res
      replyTags = {
         ['Provide-Found'] = "true",
         ['Provide-Id'] = res.id,
         ['Token'] = res.token,
         ['Quantity'] = tostring(res.quantity),
      }
   else
      replyTags = {
         ['Provide-Found'] = "false",
         ['Provide-Id'] = "0",
         ['Token'] = "0",
         ['Quantity'] = "0",
      }
   end

   responses.sendReply(msg, replyData, replyTags)
end)


Handlers.add(
"getProtocolFeePercentage",
Handlers.utils.hasMatchingTag("Action", "Get-Protocol-Fee-Percentage"),
function(msg)
   local res = pool.getProtocolFeePercentage()

   local replyData = nil
   local replyTags = { ["Protocol-Fee-Percentage"] = tostring(res) }
   responses.sendReply(msg, replyData, replyTags)

   print(
   outputs.prefix("Get-Protocol-Fee-Percentage", msg.From) ..
   Colors.gray ..
   "Protocol-Fee-Percentage = " ..
   Colors.blue ..
   tostring(res) ..
   Colors.gray ..
   "%" ..
   Colors.reset)

end)



Handlers.add(
"burn",
Handlers.utils.hasMatchingTag("Action", "Burn"),
burn.burnWithCatch)

Handlers.add(
"cancel",
Handlers.utils.hasMatchingTag("Action", "Cancel"),
cancel.cancel)










Handlers.add(
"creditNotice",
patterns.continue(Handlers.utils.hasMatchingTag("Action", "Credit-Notice")),
incoming.creditNotice)









Handlers.add(
"provide",
patterns.continue(patterns._and({
   Handlers.utils.hasMatchingTag("Action", "Credit-Notice"),
   Handlers.utils.hasMatchingTag("X-Action", "Provide"),
   function(msg) return utils.includes(msg.From, pool.getPair()) end,
})),
patterns.catchWrapper(
function(msg)
   return provide.provide(msg)
end,
"Provide"))


Handlers.add(
"swap",
patterns.continue(patterns._and({
   Handlers.utils.hasMatchingTag("Action", "Credit-Notice"),
   Handlers.utils.hasMatchingTag("X-Action", "Swap"),
   function(msg) return utils.includes(msg.From, pool.getPair()) end,
})),
patterns.catchWrapper(
function(msg)
   return swap.swap(msg)
end,
"Swap"))













Handlers.add(
"refundFinalizer",
patterns._and({
   Handlers.utils.hasMatchingTag("Action", "Credit-Notice"),
   patterns.hasMatchingTagOf("X-Action", { "Provide", "Swap" }),
   function(msg) return utils.includes(msg.From, pool.getPair()) end,
}),
refund.refund)


Handlers.add(
"whitelistForFeeDiscount",
Handlers.utils.hasMatchingTag("Action", "Whitelist-For-Fee-Discount"),
pool.handleWhitelistForFeeDiscount)


Handlers.add(
"unWhitelistForFeeDiscount",
Handlers.utils.hasMatchingTag("Action", "Un-Whitelist-For-Fee-Discount"),
pool.handleUnWhitelistForFeeDiscount)


Handlers.add(
"getWhitelistedForFeeDiscount",
Handlers.utils.hasMatchingTag("Action", "Get-Whitelisted-For-Fee-Discount"),
pool.handleGetWhitelistedForFeeDiscount)





Handlers.add(
'Get-Subscribers',
Handlers.utils.hasMatchingTag('Action', 'Debug-Get-Subscribers'),
function(msg)
   local subscribers = Subscribable._storage.Subscribers
   local replyData = subscribers
   local replyTags = nil
   responses.sendReply(msg, replyData, replyTags)
end)


Handlers.add(
'Get-Targets-For-Topic',
Handlers.utils.hasMatchingTag('Action', 'Debug-Get-Targets-For-Topic'),
function(msg)
   local topic = msg.Tags['Topic']
   local targets = Subscribable._storage.getTargetsForTopic(topic)
   local replyData = targets
   local replyTags = nil
   responses.sendReply(msg, replyData, replyTags)
end)



local subscribableCreator = require("subscriptions.subscribable")


if not Subscribable then
   Subscribable = subscribableCreator({
      useDB = false,
   })
end
Subscribable.PAYMENT_TOKEN = DexiTokenProcess
Subscribable.PAYMENT_TOKEN_TICKER = "DTST"

TopicsAndChecks = {
   ['order-confirmation'] = {
      description = 'Order confirmation details, after a swap has occurred',
      returns = 
'{ "Order-Id": string, "From-Token": string, "From-Quantity": string, "To-Token": string, "To-Quantity": string, "Fee-Percentage": string, "Reserves-Token-A": string, "Reserves-Token-B": string, "Token-A": string, "Token-B": string, "Total-Fee": string, "LP-Fee": string, "Protocol-Fee": string }',
   },
   ['liquidity-add-remove'] = {
      description = 'Latest reserves, after liquidity addition/removal',
      returns = '{ "Reserves-Token-A": bigint, "Reserves-Token-B": bigint }',
   },
   ['fee-change'] = {
      description = 'The total fee for swaps, after a fee update',
      returns = '{ "TotalFee": string }',
   },
}
Subscribable.configTopicsAndChecks(TopicsAndChecks)
