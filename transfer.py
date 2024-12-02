import aiohttp
import asyncio
import json
from typing import Dict, Optional
from decimal import Decimal
from arweave.wallets import Wallet  # 添加arweave钱包支持
from arweave.transaction import Transaction

class DexClient:
    def __init__(self, wallet_file_path: str):
        self.process_id = "N_JfhIr5Bwz6VTnbL0quOIzn4tgw3P-zxMo0jt6Mk1g"
        self.ao_url = "https://ao-api.xyz/api"
        # 初始化钱包
        with open(wallet_file_path) as wallet_file:
            wallet_json = json.load(wallet_file)
            self.wallet = Wallet(wallet_json)
    
    async def sign_and_send_message(self, tags: Dict) -> Dict:
        """签名并发送消息"""
        # 创建交易
        transaction = {
            "tags": tags,
            "target": self.process_id,
            "owner": self.wallet.address
        }
        
        # 签名交易
        signature = self.wallet.sign(json.dumps(transaction))
        
        # 添加签名到交易
        transaction["signature"] = signature
        
        # 发送交易
        async with aiohttp.ClientSession() as session:
            async with session.post(f"{self.ao_url}/message", json=transaction) as response:
                return await response.json()

    async def execute_swap(self, token: str, quantity: str) -> Dict:
        """执行swap交易"""
        # 1. 发送Credit-Notice
        credit_tags = {
            "Action": "Credit-Notice",
            "X-Action": "Swap",
            "Quantity": quantity,
            "Sender": self.wallet.address
        }
        await self.sign_and_send_message(credit_tags)
        
        # 2. 执行swap
        swap_tags = {
            "Action": "Swap",
            "Token": token,
            "Quantity": quantity,
            "Recipient": self.wallet.address
        }
        return await self.sign_and_send_message(swap_tags)

class ArbitrageBot:
    def __init__(self, wallet_file_path: str):
        self.dex = DexClient(wallet_file_path)
        self.wallet_address = self.dex.wallet.address
        
    async def monitor_prices(self):
        """监控价格变化寻找套利机会"""
        while True:
            try:
                # 1. 获取交易对信息
                pair = await self.dex.get_pair()
                
                # 2. 获取当前储备量
                reserves = await self.dex.get_reserves()
                
                # 3. 计算当前价格
                price_a_in_b = reserves[pair["token_b"]] / reserves[pair["token_a"]]
                price_b_in_a = reserves[pair["token_a"]] / reserves[pair["token_b"]]
                
                print(f"Current prices:")
                print(f"{pair['token_a']} -> {pair['token_b']}: {price_a_in_b}")
                print(f"{pair['token_b']} -> {pair['token_a']}: {price_b_in_a}")
                
                # 4. 检查套利机会
                await self.check_arbitrage_opportunity(pair, reserves)
                
                # 5. 等待一段时间再次检查
                await asyncio.sleep(10)  # 10秒检查一次
                
            except Exception as e:
                print(f"Error monitoring prices: {e}")
                await asyncio.sleep(5)
    
    async def check_arbitrage_opportunity(self, pair: Dict[str, str], reserves: Dict[str, Decimal]):
        """检查是否存在套利机会"""
        # 示例: 检查 1000 个 token_a 的交易
        test_amount = "1000"
        
        # 获取 A->B 的输出预估
        output_a_to_b = await self.dex.get_swap_output(
            pair["token_a"],
            test_amount,
            self.wallet_address
        )
        
        # 获取 B->A 的输出预估
        output_b_to_a = await self.dex.get_swap_output(
            pair["token_b"],
            output_a_to_b["tags"]["Output"],
            self.wallet_address
        )
        
        # 计算套利空间
        final_amount = Decimal(output_b_to_a["tags"]["Output"])
        initial_amount = Decimal(test_amount)
        profit = final_amount - initial_amount
        
        if profit > 0:
            profit_percentage = (profit / initial_amount) * 100
            print(f"Found arbitrage opportunity!")
            print(f"Profit: {profit} ({profit_percentage}%)")
            # 这里可以添加执行套利的逻辑
            
    async def execute_arbitrage(self, token: str, amount: str):
        """执行套利交易"""
        try:
            # 执行第一次swap
            result = await self.dex.execute_swap(token, amount)
            print(f"First swap completed: {result}")
            
            # 获取输出金额
            output_amount = result["tags"]["Output"]
            
            # 执行第二次swap (反向)
            result2 = await self.dex.execute_swap(
                result["tags"]["To-Token"], 
                output_amount
            )
            print(f"Second swap completed: {result2}")
            
            return result2
            
        except Exception as e:
            print(f"Error executing arbitrage: {e}")
            return None

async def main():
    # 初始化套利机器人，传入钱包文件路径
    bot = ArbitrageBot("./wallet.json")
    
    # 开始监控价格
    await bot.monitor_prices()

if __name__ == "__main__":
    asyncio.run(main())
