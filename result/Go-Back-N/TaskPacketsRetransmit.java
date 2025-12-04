/******************** Go-Back-N ********************/
/************ Yuwei ZHAO (2025-12-04) ************/

package com.ouc.tcp.test;

import java.util.TimerTask;

import com.ouc.tcp.client.Client;
import com.ouc.tcp.message.TCP_PACKET;

public class TaskPacketsRetransmit extends TimerTask {

    private Client senderClient;
    private TCP_PACKET[] packets;

    public TaskPacketsRetransmit(Client client, TCP_PACKET[] packets) {
        super();
        this.senderClient = client;
        this.packets = packets;
    }

    @Override
    public void run() {
        for (TCP_PACKET packet : this.packets) {
            if (packet == null) {
                break;
            } else {
                this.senderClient.send(packet);
            }
        }
    }
}