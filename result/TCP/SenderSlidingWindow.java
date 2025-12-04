/******************** Transmission-Control-Protocol ********************/
/************ Yuwei ZHAO (2025-12-05) ************/

package com.ouc.tcp.test;

import com.ouc.tcp.client.Client;
import com.ouc.tcp.client.UDT_Timer;
import com.ouc.tcp.message.TCP_PACKET;

import java.util.Hashtable;
import java.util.TimerTask;

public class SenderSlidingWindow {
    private Client client;

    private int windowSize = 16;

    private Hashtable<Integer, TCP_PACKET> packets = new Hashtable<>();
    private Hashtable<Integer, UDT_Timer> timers = new Hashtable<>();

    private int lastACKSequence = -1;

    public SenderSlidingWindow(Client client) {
        this.client = client;
    }

    public boolean isFull() {
        return this.packets.size() >= this.windowSize;
    }

    public void putPacket(TCP_PACKET packet) {
        int currentSequence = (packet.getTcpH().getTh_seq() - 1) / 100;
        this.packets.put(currentSequence, packet);
        this.timers.put(currentSequence, new UDT_Timer());
        this.timers.get(currentSequence).schedule(new RetransmitTask(this.client, packet, this), 3000, 3000);
    }

    public void receiveACK(int currentSequence) {
        if (currentSequence > this.lastACKSequence) {
            for (int i = this.lastACKSequence + 1; i <= currentSequence; i++) {
                this.packets.remove(i);
                if (this.timers.containsKey(i)) {
                    this.timers.get(i).cancel();
                    this.timers.remove(i);
                }
            }

            this.lastACKSequence = currentSequence;
            System.out.println("Window slides. Current base: " + (this.lastACKSequence + 1));
        }
    }
}

class RetransmitTask extends TimerTask {
    private Client client;
    private TCP_PACKET packet;
    private SenderSlidingWindow window;

    public RetransmitTask(Client client, TCP_PACKET packet, SenderSlidingWindow window) {
        this.client = client;
        this.packet = packet;
        this.window = window;
    }

    @Override
    public void run() {
        System.out.println("Timeout! Retransmitting packet seq: " + packet.getTcpH().getTh_seq());
        this.client.send(this.packet);
    }
}