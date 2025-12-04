/******************** RDT 2.2 ********************/
/************ Yuwei ZHAO (2025-12-04) ************/

package com.ouc.tcp.test;

import com.ouc.tcp.client.TCP_Receiver_ADT;
import com.ouc.tcp.message.*;

import java.io.BufferedWriter;
import java.io.File;
import java.io.FileWriter;
import java.io.IOException;

public class TCP_Receiver extends TCP_Receiver_ADT {
    private TCP_PACKET ackPack; // Reply to ACK message segment
    private int lastSequence = -1; // Used to record the current sequence number of the packet to be received. Note that the packet sequence number is not entirely accurate.

    /* Constructor Func */
    public TCP_Receiver() {
        super(); // Call the constructor of the superclass
        super.initTCP_Receiver(this); // Initialize the TCP receiver side
    }

    @Override
    public void rdt_recv(TCP_PACKET recvPack) { // Received data packet - Check the checksum, and set the reply ACK message segment
        // Received data packet - Check the checksum, and set the reply ACK message segment
        if (CheckSum.computeChkSum(recvPack) == recvPack.getTcpH().getTh_sum()) {
            this.tcpH.setTh_ack(recvPack.getTcpH().getTh_seq());
            this.ackPack = new TCP_PACKET(this.tcpH, this.tcpS, recvPack.getSourceAddr());
            this.tcpH.setTh_sum(CheckSum.computeChkSum(this.ackPack));

            System.out.println();
            System.out.println("ACK: " + recvPack.getTcpH().getTh_seq());
            System.out.println();

            // Reply to ACK message segment
            reply(this.ackPack);

            int currentSequence = (recvPack.getTcpH().getTh_seq() - 1) / 100;
            if (currentSequence != this.lastSequence) {
                this.lastSequence = currentSequence;

                // Insert the received correct and ordered data into the data queue, preparing for delivery
                this.dataQueue.add(recvPack.getTcpS().getData());

                // Deliver data (per 20 sets of data)
                if (this.dataQueue.size() == 20)
                    deliver_data();
            }
        } else {
            // Generate NACK message segment
            this.tcpH.setTh_ack(this.lastSequence * 100 + 1);
            this.ackPack = new TCP_PACKET(this.tcpH, this.tcpS, recvPack.getSourceAddr());
            this.tcpH.setTh_sum(CheckSum.computeChkSum(this.ackPack));

            System.out.println();
            System.out.println("ACK last sequence: " + this.lastSequence);
            System.out.println();

            reply(this.ackPack);
        }
    }

    @Override
    public void deliver_data() { // Deliver data (write data to file); no modifications required
        // Check the `this.dataQueue` and write the data to the file
        try {
            File file = new File("recvData.txt");
            BufferedWriter writer = new BufferedWriter(new FileWriter(file, true));

            while (!this.dataQueue.isEmpty()) {
                int[] data = this.dataQueue.poll();

                // Write data to a file
                for (int i = 0; i < data.length; i++) {
                    writer.write(data[i] + "\n");
                }

                writer.flush(); // Clear out caches
            }

            writer.close();
        } catch (IOException e) {
            e.printStackTrace();
        }
    }

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
        this.tcpH.setTh_eflag((byte) 1);

        // Send data packet
        this.client.send(replyPack);
    }
}