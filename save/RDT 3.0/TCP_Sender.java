/******************** RDT 3.0 ********************/
/************ Yuwei ZHAO (2025-12-04) ************/

package com.ouc.tcp.test;

import com.ouc.tcp.client.TCP_Sender_ADT;
import com.ouc.tcp.client.UDT_RetransTask;
import com.ouc.tcp.client.UDT_Timer;
import com.ouc.tcp.message.*;

public class TCP_Sender extends TCP_Sender_ADT {
    private TCP_PACKET tcpPack; // The TCP data packet to be sent
    private volatile int flag = 0;

    private UDT_Timer timer;
    private UDT_RetransTask task;

    /* Constructor Func */
    public TCP_Sender() {
        super(); // Call the constructor of the superclass
        super.initTCP_Sender(this); // Initialize the TCP receiver side
    }

    @Override
    public void rdt_send(int dataIndex, int[] appData) { // Reliable transmission (application layer call): Encapsulate application layer data and generate TCP data packets; Need to be revised
        // Generate the TCP data packet (set the sequence number, data field, and checksum), and pay attention to the order of packaging
        this.tcpH.setTh_seq(dataIndex * appData.length + 1); // Set the package number to the byte stream number
        this.tcpS.setData(appData);
        this.tcpPack = new TCP_PACKET(this.tcpH, this.tcpS, this.destinAddr);

        this.tcpH.setTh_sum(CheckSum.computeChkSum(this.tcpPack));
        this.tcpPack.setTcpH(this.tcpH);

        this.timer = new UDT_Timer();
        this.task = new UDT_RetransTask(this.client, this.tcpPack);
        this.timer.schedule(this.task, 3000, 3000);

        // Send TCP data packet
        udt_send(this.tcpPack);
        this.flag = 0;

        // Wait for the ACK message
        // waitACK();
        while (this.flag == 0) ;
    }

    @Override
    public void udt_send(TCP_PACKET stcpPack) { // Unreliable transmission - Send the packaged TCP data packet through an unreliable transmission channel; only the error flag needs to be modified.
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
        this.tcpH.setTh_eflag((byte) 4);

        // Send data packet
        this.client.send(stcpPack);
    }

    @Override
    public void waitACK() {
        // Loop-check `this.ackQueue`
        // Loop-check to confirm if there are any newly received ACKs in the confirmation number column.
        if (!this.ackQueue.isEmpty()) {
            int currentACK = this.ackQueue.poll();
            // System.out.println("CurrentAck: " + currentAck);
            if (currentACK == this.tcpPack.getTcpH().getTh_seq()) {
                System.out.println();
                System.out.println("Clear: " + currentACK);
                System.out.println();

                this.timer.cancel();

                this.flag = 1;
                // break;
            }
        }
    }

    @Override
    public void recv(TCP_PACKET recvPack) { // Received ACK message: Check the checksum, insert the confirmation number into the ack queue; The confirmation number for NACK is -1; No modification is required.
        if (CheckSum.computeChkSum(recvPack) == recvPack.getTcpH().getTh_sum()) {
            System.out.println();
            System.out.println("Receive ACK Number: " + recvPack.getTcpH().getTh_ack());
            System.out.println();

            this.ackQueue.add(recvPack.getTcpH().getTh_ack());
        } else {
            System.out.println();
            System.out.println("Receive corrupt ACK: " + recvPack.getTcpH().getTh_ack());
            System.out.println();

            this.ackQueue.add(-1);
        }

        // Process the ACK message
        waitACK();
    }
}