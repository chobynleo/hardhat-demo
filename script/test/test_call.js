const { ethers, network } = require("hardhat");
const { BigNumber } = require("ethers");



async function main() {
    let [owner] = await ethers.getSigners();

    // struct Unbonds {
    //     uint256 shares;
    //     uint256 withdrawEpoch;
    //     uint256 unbondNonce;
    // }
    // function getUnbondByNonce(
    //     address validator, 
    //     address user
    // ) external view returns(Unbonds[] memory unbond0, Unbonds[] memory unbond1) {}
    let ABI = [
        "function swapExactTokensForTokens(uint amountIn,uint amountOutMin,address[] calldata path,address to,uint deadline) external returns (uint[] memory amounts)",
        "function getUnbondByNonce(address validator,address user) external view returns(tuple(uint,uint,uint)[] memory unbond0, tuple(uint,uint,uint)[] memory unbond1)",
    ]

    let iface = new ethers.utils.Interface(ABI);
    
    let data = iface.encodeFunctionData("getUnbondByNonce", [
        "0x8BcaFD2E2e0C6a44453CdE72fd37246AB4a277d2",
        "0x78D36B4596240da272Cc039B4d682CcE72C44664",
      ])
    // console.log(data)
    let res =  await secondSigner.call(  
                    {
                        to:"0x6290C8000d266d8a850F2F2EaE733857637688f7",
                        data:data,
                        gasLimit: 10000000,
                    }
                )
    // different from owner.sendTransaction({from: owner.address, data: '0x600a600c602039600a6020f3602a60605260206060f3', gasLimit: 10000000})
    // sendTransaction is write-action, not only-read-action
    // to use provider not signer, if use from signer, it can not be change from address
    // let res =  await secondSigner.provider.call(  
    //     {
    //         from: address,    
    //         to:"0x6290C8000d266d8a850F2F2EaE733857637688f7",
    //         data:data,
    //         gasLimit: 10000000,
    //     }
    // )
    // as the same as static call 
    // let poolCon = new ethers.Contract("0xe222fBE074A436145b255442D919E4E3A6c6a480", ABI, mockSigner.provider);
    // console.log("syncFeeGrowth", await poolCon.callStatic.func1(arg1, {from: add1}))
    
    console.log(res)
    //res = "0x000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000c00000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000048fdbf5533c0b50000000000000000000000000000000000000000000000000000000000000000af8400000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000"
    
    let decodeData =  iface.decodeFunctionResult("getUnbondByNonce", res);
    console.log(decodeData)

}

main()
    .then(() =>process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
