/******************** Transmission-Control-Protocol ********************/
/************ Yuwei ZHAO (2025-12-05) ************/

package com.ouc.tcp.test;

import com.ouc.tcp.client.TCP_Sender_ADT;
import com.ouc.tcp.client.UDT_RetransTask;
import com.ouc.tcp.client.UDT_Timer;
import com.ouc.tcp.message.*;

public class TCP_Sender extends TCP_Sender_ADT {
    private TCP_PACKET tcpPack; // The TCP data packet to be sent
    private volatile int flag = 1;

    private SenderSlidingWindow window = new SenderSlidingWindow(this.client);

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

        System.out.println();
        System.out.println("window size: " + this.window.cwnd);
        System.out.println();

        if (this.window.isFull()) {
            System.out.println();
            System.out.println("Sliding Window Full");
            System.out.println();

            this.flag = 0;
        }
        while (this.flag == 0) ;

        try {
            this.window.putPacket(this.tcpPack.clone());
        } catch (CloneNotSupportedException e) {
            e.printStackTrace();
        }

        // Send TCP data packet
        udt_send(this.tcpPack);
        // this.flag = 0;

        // Wait for the ACK message
        // waitACK();
        // while (this.flag == 0) ;
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
        this.tcpH.setTh_eflag((byte) 7);

        // Send data packet
        this.client.send(stcpPack);
    }

    @Override
    public void waitACK() { }

    @Override
    public void recv(TCP_PACKET recvPack) { // Received ACK message: Check the checksum, insert the confirmation number into the ack queue; The confirmation number for NACK is -1; No modification is required.
        if (CheckSum.computeChkSum(recvPack) == recvPack.getTcpH().getTh_sum()) {
            System.out.println();
            System.out.println("Receive ACK Number: " + recvPack.getTcpH().getTh_ack());
            System.out.println();

            this.window.receiveACK((recvPack.getTcpH().getTh_ack() - 1) / 100);
            if (!this.window.isFull()) {
                this.flag = 1;
            }
        }
        // Process the ACK message
        // waitACK();
    }
}