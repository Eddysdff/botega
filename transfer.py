import json
import time
import asyncio
import base64
from typing import Dict
from arweave import Wallet
import requests

# 定义币对配置
TOKENS = {
    "wAR": "xU9zFkq3X2ZQ6olwNVvr1vUWIjc3kXTWr7xKQD6dh10",
    "qAR": "NG-0lVX882MG5nhARrSzyprEK6ejonHpdUmaaMPsHE8",
    "agent": "8rbAftv7RaPxFjFk5FGUVAVCSjGQB4JHDcb9P9wCVhQ"
}

PAIRS = [
    ("wAR", "qAR"),
    ("wAR", "agent"),
    ("qAR", "agent")
]

class DexClient:
    def __init__(self, wallet_file_path: str):
        self.process_id = "N_JfhIr5Bwz6VTnbL0quOIzn4tgw3P-zxMo0jt6Mk1g"
        # 初始化钱包 - 直接传入文件路径
        self.wallet = Wallet(wallet_file_path)
        
        # AO API endpoint
        self.ao_url = "https://cu2800.ao-testnet.xyz/"  # AO API endpoint

    def sign_message(self, tags: Dict) -> Dict:
        """签名消息"""
        # 创建交易
        transaction = {
            "tags": tags,
            "target": self.process_id,
            "owner": self.wallet.address
        }
        
        # 将交易转换为JSON字符串并签名
        tx_data = json.dumps(transaction)
        signature = self.wallet.sign(tx_data.encode('utf-8'))
        
        signature_b64 = base64.b64encode(signature).decode('utf-8')
        
        # 添加签名到交易
        transaction["signature"] = signature_b64
        
        return transaction

    async def get_result(self, message_id: str) -> Dict:
        """获取消息结果，类似于aoconnect的result函数"""
        try:
            print(f"Getting result for message: {message_id}")
            response = requests.get(
                f"{self.ao_url}/result", 
                params={
                    "message": message_id,
                    "process": self.process_id
                }
            )
            
            print(f"Result response status: {response.status_code}")
            print(f"Result content: {response.text}")
            
            if response.status_code == 200:
                try:
                    result = response.json()
                    return {
                        "Messages": result.get("Messages", []),
                        "Spawns": result.get("Spawns", []),
                        "Output": result.get("Output", {}),
                        "Error": result.get("Error")
                    }
                except json.JSONDecodeError as e:
                    print(f"Failed to parse result as JSON: {response.text}")
                    return None
            else:
                print(f"Failed to get result: {response.text}")
                return None
                
        except Exception as e:
            print(f"Error getting result: {e}")
            return None

    async def send_and_wait(self, tags: Dict) -> Dict:
        """发送消息并等待结果"""
        try:
            # 签名消息
            signed_tx = self.sign_message(tags)
            
            # 打印请求数据用于调试
            print(f"Sending request to AO API:")
            print(f"URL: {self.ao_url}/message")
            print(f"Data: {json.dumps(signed_tx, indent=2)}")
            
            # 发送到AO
            headers = {
                'Content-Type': 'application/json'
            }
            response = requests.post(
                f"{self.ao_url}/message",
                json=signed_tx,
                headers=headers
            )
            
            # 打印响应数据用于调试
            print(f"Response status code: {response.status_code}")
            print(f"Response content: {response.text}")
            
            if response.status_code != 200:
                raise Exception(f"Failed to send message: {response.text}")
            
            try:
                response_data = response.json()
            except json.JSONDecodeError as e:
                print(f"Failed to parse response as JSON: {response.text}")
                raise Exception(f"Invalid JSON response: {e}")
                
            message_id = response_data.get("id")
            if not message_id:
                raise Exception("No message ID in response")
            
            # 等待并获取结果
            max_attempts = 10
            attempt = 0
            
            while attempt < max_attempts:
                result = await self.get_result(message_id)
                if result:
                    if result.get("Error"):
                        raise Exception(f"Transaction failed: {result['Error']}")
                    return result
                
                attempt += 1
                await asyncio.sleep(2)  # 等待2秒后重试
                
            raise Exception("Failed to get transaction result")
            
        except Exception as e:
            print(f"Error in send_and_wait: {e}")
            return None

    async def get_swap_output(self, token: str, quantity: str) -> Dict:
        """获取swap输出预估"""
        try:
            tags = {
                "Action": "Get-Swap-Output",
                "Token": token,
                "Quantity": quantity,
                "Swapper": self.wallet.address
            }
            return await self.send_and_wait(tags)
        except Exception as e:
            print(f"Error in get_swap_output: {e}")
            return None

class ArbitrageBot:
    def __init__(self, wallet_file_path: str):
        self.dex = DexClient(wallet_file_path)
        self.wallet_address = self.dex.wallet.address
        
    async def monitor_prices(self):
        """监控价格变化寻找套利机会"""
        while True:
            try:
                # 检查所有币对的套利机会
                for token1_name, token2_name in PAIRS:
                    token1_id = TOKENS[token1_name]
                    token2_id = TOKENS[token2_name]
                    print(f"\nChecking pair {token1_name}-{token2_name}...")
                    await self.check_arbitrage_opportunity(token1_id, token2_id, token1_name, token2_name)
                
                await asyncio.sleep(10)  # 10秒检查一次
                
            except Exception as e:
                print(f"Error monitoring prices: {e}")
                await asyncio.sleep(5)

    async def check_arbitrage_opportunity(self, token_a: str, token_b: str, token_a_name: str, token_b_name: str):
        """检查是否存在套利机会"""
        test_amount = "1000"  # 测试金额
        
        try:
            # 获取 A->B 的输出预估
            print(f"Checking {token_a_name} -> {token_b_name}...")
            output_a_to_b = await self.dex.get_swap_output(token_a, test_amount)
            
            if output_a_to_b and output_a_to_b.get("Output"):
                output_amount = output_a_to_b["Output"]["tags"]["Output"]
                print(f"{test_amount} {token_a_name} -> {output_amount} {token_b_name}")
                
                # 获取 B->A 的输出预估
                print(f"Checking {token_b_name} -> {token_a_name}...")
                output_b_to_a = await self.dex.get_swap_output(token_b, output_amount)
                
                if output_b_to_a and output_b_to_a.get("Output"):
                    final_amount = int(output_b_to_a["Output"]["tags"]["Output"])
                    initial_amount = int(test_amount)
                    profit = final_amount - initial_amount
                    
                    print(f"{output_amount} {token_b_name} -> {final_amount} {token_a_name}")
                    
                    if profit > 0:
                        print(f"Found arbitrage opportunity in {token_a_name}-{token_b_name}!")
                        print(f"Profit: {profit} {token_a_name} ({(profit/initial_amount)*100:.2f}%)")
                    else:
                        print(f"No arbitrage opportunity found in {token_a_name}-{token_b_name}")
                        print(f"Loss: {profit} {token_a_name} ({(profit/initial_amount)*100:.2f}%)")
                else:
                    print(f"Failed to get {token_b_name}->{token_a_name} output estimate.")
            else:
                print(f"Failed to get {token_a_name}->{token_b_name} output estimate.")
        except Exception as e:
            print(f"Error checking arbitrage opportunity: {e}")

async def main():
    # 初始化套利机器人
    bot = ArbitrageBot(r"E:\blockchain\ARWEAVE\botega\wallet.json")
    
    # 开始监控价格
    await bot.monitor_prices()

if __name__ == "__main__":
    asyncio.run(main())