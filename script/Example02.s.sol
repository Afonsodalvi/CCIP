// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Script } from "forge-std/Script.sol";
import { console2 } from "forge-std/console2.sol";
import "./Helper.sol";
import {BasicMessageReceiver} from "../src/BasicMessageReceiver.sol";
import {IRouterClient} from "@chainlink/contracts-ccip/ccip/interfaces/IRouterClient.sol";
import {Client} from "@chainlink/contracts-ccip/ccip/libraries/Client.sol";
import {IERC20} from "@chainlink/contracts-ccip/vendor/openzeppelin-solidity/v4.8.0/contracts/token/ERC20/IERC20.sol";

contract DeployBasicMessageReceiver is Script, Helper {
    function run(SupportedNetworks destination) external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        (address router, , , ) = getConfigFromNetwork(destination);

        BasicMessageReceiver basicMessageReceiver = new BasicMessageReceiver(
            router
        );

        console2.log(
            "Basic Message Receiver deployed on ",
            networks[destination],
            "with address: ",
            address(basicMessageReceiver)
        );

        vm.stopBroadcast();
    }
}

contract CCIPTokenTransfer is Script, Helper {
    function run(
        SupportedNetworks source,
        SupportedNetworks destination,
        address basicMessageReceiver,
        address tokenToSend,
        uint256 amount,
        PayFeesIn payFeesIn
    ) external returns (bytes32 messageId) {
        uint256 senderPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(senderPrivateKey);

        (address sourceRouter, address linkToken, , ) = getConfigFromNetwork(
            source
        );
        (, , , uint64 destinationChainId) = getConfigFromNetwork(destination);

        IERC20(tokenToSend).approve(sourceRouter, amount);

        Client.EVMTokenAmount[]
            memory tokensToSendDetails = new Client.EVMTokenAmount[](1);
        Client.EVMTokenAmount memory tokenToSendDetails = Client
            .EVMTokenAmount({token: tokenToSend, amount: amount});

        tokensToSendDetails[0] = tokenToSendDetails;

        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(basicMessageReceiver),
            data: "",
            tokenAmounts: tokensToSendDetails,
            extraArgs: "",
            feeToken: payFeesIn == PayFeesIn.LINK ? linkToken : address(0)
        });

        uint256 fees = IRouterClient(sourceRouter).getFee(
            destinationChainId,
            message
        );

        if (payFeesIn == PayFeesIn.LINK) {
            IERC20(linkToken).approve(sourceRouter, fees);
            messageId = IRouterClient(sourceRouter).ccipSend(
                destinationChainId,
                message
            );
        } else {
            messageId = IRouterClient(sourceRouter).ccipSend{value: fees}(
                destinationChainId,
                message
            );
        }

        console2.log(
            "You can now monitor the status of your Chainlink CCIP Message via https://ccip.chain.link using CCIP Message ID: "
        );
        console2.logBytes32(messageId);

        vm.stopBroadcast();
    }
}

contract GetLatestMessageDetails is Script, Helper {
    function run(address basicMessageReceiver) external view {
        (
            bytes32 latestMessageId,
            uint64 latestSourceChainSelector,
            address latestSender,
            string memory latestMessage
        ) = BasicMessageReceiver(basicMessageReceiver).getLatestMessageDetails();

        console2.log("Latest Message ID: ");
        console2.logBytes32(latestMessageId);
        console2.log("Latest Source Chain Selector: ");
        console2.log(latestSourceChainSelector);
        console2.log("Latest Sender: ");
        console2.log(latestSender);
        console2.log("Latest Message: ");
        console2.log(latestMessage);
    }
}
