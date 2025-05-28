
实现一个LunchPad：
修改之前最小代理工厂 1% 费用修改为 5%， 然后 5% 的 ETH 与相应的 Token 调用 Uniswap V2Router AddLiquidity 添加MyToken与 ETH 的流动性（如果是第一次添加流动性按mint 价格作为流动性价格）。

除了之前的 mintMeme() 可以购买 meme 外，添加一个方法: buyMeme()， 以便在 Unswap 的价格优于设定的起始价格时，用户可调用该函数来购买 Meme.  
