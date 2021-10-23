import { parseEther } from "ethers/lib/utils";
import { task } from "hardhat/config";
import { HardhatRuntimeEnvironment } from "hardhat/types";

interface TaskArguments {
    verify: boolean;
    nativeCurrencyCost: string;
    freeMintable: string;
    paidMintable: string;
    whitelistMintable: string;
}

task(
    "deploy",
    "Deploys the NFP contract and (optionally) verifies the source code on Etherscan."
)
    .addParam(
        "nativeCurrencyCost",
        "The cost that the user will initially incur when minting a NFP."
    )
    .addParam("freeMintable", "The amount of NFPs mintable for free.")
    .addParam("paidMintable", "The amount of NFPs mintable by paying.")
    .addParam(
        "whitelistMintable",
        "The amount of NFPs mintable through whitelisting."
    )
    .addFlag(
        "verify",
        "Additional (and optional) Etherscan contracts verification"
    )
    .setAction(
        async (
            {
                verify,
                nativeCurrencyCost,
                freeMintable,
                paidMintable,
                whitelistMintable,
            }: TaskArguments,
            hre: HardhatRuntimeEnvironment
        ) => {
            await hre.run("clean");
            await hre.run("compile");

            const nfpFactory = await hre.ethers.getContractFactory("NFP");
            const nfp = await nfpFactory.deploy(
                "Non fungible profile",
                "NFP",
                parseEther(nativeCurrencyCost),
                freeMintable,
                paidMintable,
                whitelistMintable
            );
            await nfp.deployed();

            if (verify) {
                await new Promise((resolve) => {
                    console.log("Waiting before source code verification...");
                    setTimeout(resolve, 60000);
                });

                console.log("Verifying NFP source code");
                await hre.run("verify", {
                    address: nfp.address,
                    constructorArgsParams: [
                        "Non fungible profile",
                        "NFP",
                        parseEther(nativeCurrencyCost).toString(),
                        freeMintable,
                        paidMintable,
                        whitelistMintable,
                    ],
                });

                console.log("Source code verified");
            }

            console.log(`NFP deployed at address ${nfp.address}`);
        }
    );
