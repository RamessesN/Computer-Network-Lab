/******************** TCP-Reno ********************/
/************ Yuwei ZHAO (2025-12-05) ************/

package com.ouc.tcp.test;

import com.ouc.tcp.client.TCP_Receiver_ADT;
import com.ouc.tcp.message.TCP_PACKET;

public class TCP_Receiver extends TCP_Receiver_ADT {
    private TCP_PACKET ackPack; // Reply to ACK message segment

    private ReceiverSlidingWindow window = new ReceiverSlidingWindow(this.client);

    /* Constructor Func */
    public TCP_Receiver() {
        super(); // Call the constructor of the superclass
        super.initTCP_Receiver(this); // Initialize the TCP receiver side
    }

    @Override
    public void rdt_recv(TCP_PACKET recvPack) {
        // Received data packet - Check the checksum, and set the reply ACK message segment
        if (CheckSum.computeChkSum(recvPack) == recvPack.getTcpH().getTh_sum()) {
            int toACKSequence = -1;
            try {
                toACKSequence = this.window.receivePacket(recvPack.clone());
            } catch (CloneNotSupportedException e) {
                e.printStackTrace();
            }

            this.tcpH.setTh_ack(toACKSequence * 100 + 1);
            this.ackPack = new TCP_PACKET(this.tcpH, this.tcpS, recvPack.getSourceAddr());
            this.tcpH.setTh_sum(CheckSum.computeChkSum(this.ackPack));

            // Reply to ACK message segment
            reply(this.ackPack);
        } else {
            System.out.println("CheckSum Error: Packet Corrupted.");

            if (this.ackPack != null) {
                reply(this.ackPack);
            }
        }
    }

    @Override
    public void deliver_data() { }

    @Override
    public void reply(TCP_PACKET replyPack) { // Reply to the ACK message segment
        /*
            <- Error control flag Setting ->
            - eFlag = 0: Channel error-free
            - eFlag = 1: Only errors
            - eFlag = 2: Only packet loss
            - eFlag = 3: Only delay
            - eFlag = 4: Errors / Packet loss
            - eFlag = 5: Errors / Delay
            - eFlag = 6: Packet loss / Delay
            - eFlag = 7: Errors / Packet loss / Delay
        */
        this.tcpH.setTh_eflag((byte) 7);

        // Send data packet
        this.client.send(replyPack);
    }
}