const {
    createDataItemSigner,
    message,
    result
} = require("@permaweb/aoconnect");
const Arweave = require('arweave');
const fs = require('fs');
const path = require('path');

// 初始化 Arweave
const arweave = Arweave.init({
    host: 'arweave.net',
    port: 443,
    protocol: 'https'
});

// 定义钱包文件路径
const WALLET_FILE_PATH = path.join(__dirname, 'wallet.json');
// 确保钱包文件存在
if (!fs.existsSync(WALLET_FILE_PATH)) {
    console.error('Wallet file not found at:', WALLET_FILE_PATH);
    process.exit(1);
}

// 定义币对配置，包含精度信息
const TOKENS = {
    "wAR": {
        id: "xU9zFkq3X2ZQ6olwNVvr1vUWIjc3kXTWr7xKQD6dh10",
        denomination: 12
    },
    "qAR": {
        id: "NG-0lVX882MG5nhARrSzyprEK6ejonHpdUmaaMPsHE8",
        denomination: 12
    },
    "agent": {
        id: "8rbAftv7RaPxFjFk5FGUVAVCSjGQB4JHDcb9P9wCVhQ",
        denomination: 18
    }
};

const PAIRS = [
    ["wAR", "qAR"],
    ["wAR", "agent"],
    ["qAR", "agent"]
];

// 辅助函数：将普通数字转换为链上使用的大数
function toChainValue(amount, decimals) {
    return BigInt(amount) * BigInt(10) ** BigInt(decimals);
}

// 辅助函数：将链上大数转换为普通数字
function fromChainValue(amount, decimals) {
    return Number(amount) / (10 ** decimals);
}

class DexClient {
    constructor(walletFilePath) {
        this.processId = "N_JfhIr5Bwz6VTnbL0quOIzn4tgw3P-zxMo0jt6Mk1g";
        
        try {
            this.wallet = JSON.parse(fs.readFileSync(walletFilePath));
            this.walletAddress = arweave.wallets.jwkToAddress(this.wallet).then(address => {
                console.log('Wallet address:', address);
                return address;
            });
            this.signer = createDataItemSigner(this.wallet);
        } catch (error) {
            console.error('Error initializing DexClient:', error);
            throw error;
        }
    }

    async sendMessage(tags) {
        try {
            const address = await this.walletAddress;
            console.log('Sending message with tags:', tags);

            // 生成唯一的消息ID
            const messageId = `${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;

            const messageData = {
                process: this.processId,
                tags: tags, // 直接使用传入的tags数组
                signer: this.signer,
            };

            console.log('Sending message with data:', messageData);
            const sentMessageId = await message(messageData);
            console.log('Message sent, ID:', sentMessageId);
            
            const res = await result({
                message: sentMessageId,
                process: this.processId
            });
            
            console.log('Result received:', res);
            return res;
        } catch (error) {
            console.error('Error sending message:', error);
            throw error;
        }
    }

    async getReserves() {
        try {
            const tags = [
                { name: "Action", value: "Get-Reserves" }
            ];
            const result = await this.sendMessage(tags);
            if (result && result.Output && result.Output.tags) {
                // 将结果转换为BigInt
                const reserves = {};
                for (const [token, value] of Object.entries(result.Output.tags)) {
                    if (token !== 'Action') {
                        reserves[token] = BigInt(value);
                    }
                }
                return reserves;
            }
            return null;
        } catch (error) {
            console.error('Error in getReserves:', error);
            return null;
        }
    }

    async getSwapOutput(token, quantity) {
        try {
            const address = await this.walletAddress;
            const tags = [
                { name: "Action", value: "Get-Swap-Output" },
                { name: "Token", value: token },
                { name: "Quantity", value: String(quantity) },
                { name: "Swapper", value: address }
            ];

            return await this.sendMessage(tags);
        } catch (error) {
            console.error('Error in getSwapOutput:', error);
            return null;
        }
    }
}

class ArbitrageBot {
    constructor(walletFilePath) {
        this.dex = new DexClient(walletFilePath);
        this.wallet = JSON.parse(fs.readFileSync(walletFilePath));
    }

    async checkArbitrageOpportunity(token1Name, token2Name) {
        try {
            const token1 = TOKENS[token1Name];
            const token2 = TOKENS[token2Name];
            const testAmount = 1000; // 基础单位，将被转换为链上值

            // 获取当前储备金
            const reserves = await this.dex.getReserves();
            if (reserves) {
                console.log('\nCurrent Reserves:');
                console.log(`${token1Name}: ${fromChainValue(reserves[token1.id], token1.denomination)}`);
                console.log(`${token2Name}: ${fromChainValue(reserves[token2.id], token2.denomination)}`);
            }

            // 检查 token1 -> token2
            console.log(`\nChecking ${token1Name} -> ${token2Name}...`);
            const chainAmount = toChainValue(testAmount, token1.denomination);
            const output1to2 = await this.dex.getSwapOutput(token1.id, chainAmount.toString());
            
            if (output1to2 && output1to2.Output) {
                const normalizedOutput1to2 = fromChainValue(BigInt(output1to2.Output), token2.denomination);
                console.log(`${testAmount} ${token1Name} -> ${normalizedOutput1to2} ${token2Name}`);

                // 检查 token2 -> token1 的返回路径
                const chainAmount2 = toChainValue(normalizedOutput1to2, token2.denomination);
                const output2to1 = await this.dex.getSwapOutput(token2.id, chainAmount2.toString());

                if (output2to1 && output2to1.Output) {
                    const finalAmount = fromChainValue(BigInt(output2to1.Output), token1.denomination);
                    const profit = finalAmount - testAmount;
                    const profitPercentage = (profit / testAmount) * 100;

                    console.log(`${normalizedOutput1to2} ${token2Name} -> ${finalAmount} ${token1Name}`);
                    
                    if (profit > 0) {
                        console.log(`Found arbitrage opportunity!`);
                        console.log(`Profit: ${profit} ${token1Name} (${profitPercentage.toFixed(2)}%)`);
                    } else {
                        console.log(`No arbitrage opportunity`);
                        console.log(`Loss: ${profit} ${token1Name} (${profitPercentage.toFixed(2)}%)`);
                    }
                }
            }
        } catch (error) {
            console.error('Error checking arbitrage opportunity:', error);
        }
    }

    async monitorPrices() {
        while (true) {
            try {
                for (const [token1Name, token2Name] of PAIRS) {
                    console.log(`\nChecking pair ${token1Name}-${token2Name}...`);
                    await this.checkArbitrageOpportunity(token1Name, token2Name);
                }
                await new Promise(resolve => setTimeout(resolve, 10000));
            } catch (error) {
                console.error('Error monitoring prices:', error);
                await new Promise(resolve => setTimeout(resolve, 5000));
            }
        }
    }
}

// 主函数
async function main() {
    try {
        const bot = new ArbitrageBot(WALLET_FILE_PATH);
        await bot.monitorPrices();
    } catch (error) {
        console.error('Error in main:', error);
    }
}

main();
