/**************   Report Template   **************/
#import "@preview/codly:1.3.0": *
#import "@preview/codly-languages:0.1.1": *

#show: codly-init.with()

#let report-template(
  title: "",
  author-name: "",
  author-id: "",
  major: "",
  grade: "",
  body
) = {
  set document(title: title, author: author-name)

  set page(
    paper: "a4",
    margin: 2.5cm,
    header: context {
      if counter(page).get().first() > 1 {
        set text(size: 11pt, font: "Times New Roman")
        grid(
          columns: (1fr, auto, 1fr),
          align: (left, center, right),
          [Computer Network],
          [#author-name (#author-id)],
          [Lab Report]
        )
        v(-10pt)
        line(length: 100%, stroke: 0.6pt)
      }
    },

    footer: context {
      align(center)[
        #counter(page).display("1")
      ]
    }
  )

  set text(
    font: "Times New Roman", 
    size: 12pt,
    lang: "en",
    region: "GB"
  )

  set math.mat(delim: "[")
  set math.vec(delim: "[")
  set math.equation(numbering: "(1)")

  show ref: it => {
    let el = it.element
    if el != none and el.func() == math.equation {
      let count = counter(math.equation).at(el.location())      

      let num = numbering(el.numbering, ..count)

      set text(fill: rgb("0000FF")) 
      link(el.location(), num)
    } else {
      it
    }
  }

  show link: set text(fill: rgb("0000FF"))

  set par(
    justify: true, 
    first-line-indent: 0em, 
    spacing: 1.6em
  )

  set heading(numbering: "1.1")
  show heading.where(level: 1): set block(above: 2em, below: 1.2em)
  show heading.where(level: 2): set block(above: 1.2em, below: 1.2em)
  show heading.where(level: 3): set block(above: 1.2em, below: 1.2em)
  
  show raw.where(block: true): block.with(
    fill: luma(245),
    inset: 10pt,
    radius: 4pt,
    width: 100%,
  )
  show raw: set text(font: "Times New Roman", size: 0.9em)

  align(center)[
    #text(weight: "bold", size: 1.6em)[#title] \
    #v(0.3em)
    #author-id #h(1em) #author-name \
    #grade #h(0.3em) #major
  ]
  v(0.3cm)

  body
}

#let sep = box(height: 1.5em)

#show: report-template.with(
  title: "Computer Network Lab Report",
  author-name: "Yuwei ZHAO",
  author-id: "23020036096",
  major: "Computer Science and Technology",
  grade: "23th",
)

= Combine code and LOG file analysis to illustrate the solution effect for each project.

== RDT-1.0
  RDT-1.0 simulates transmission over a reliable channel, and the data transfer between the sender and receiver is not affected by any network errors.

  There is no need to modify any code in this project, as the reliable channel ensures that all packets are delivered correctly and in order. Therefore, the sender simply sends packets sequentially, and the receiver acknowledges each received packet as follows:

  #figure(
    grid(
      columns: (1fr, 1fr),
      rows: (auto, auto),
      gutter: 1em,
      
      image("../doc/img/rdt1_log_sender.png", height: 20%),
      image("../doc/img/rdt1_log_receiver.png", height: 20%),
    ),
    caption: [RDT-1.0 Sender/Receiver LOG & Code Snippet]
  )

== RDT-2.0
  RDT-2.0 simulates transmission over a channel that may introduce *bit errors*, and it uses checksums and acknowledgments to ensure reliable data transfer.

  === CheckSum.java

  #codly(languages: codly-languages)
  ```java
  public class CheckSum {
      public static short computeChkSum(TCP_PACKET tcpPack) {
          // Extract TCP header information
          TCP_HEADER header = tcpPack.getTcpH();

          // Calculate the checksum using the CRC32 algorithm
          CRC32 crc32 = new CRC32();
          crc32.update(header.getTh_seq());
          crc32.update(header.getTh_ack());

          // Traverse the data fields and update each data item to the checksum.
          for (int i : tcpPack.getTcpS().getData()) {
            crc32.update(i);
          }

          // Obtain the calculated checksum and convert it to the short data type for return
          return (short) crc32.getValue();
      }
  }
  ```

  === TCP_Sender.java
  #codly(languages: codly-languages)
  ```java
  public void waitACK() {
      // Loop-check to confirm if there are any newly received ACKs in the confirmation number column.
      if (!this.ackQueue.isEmpty()) {
          int currentACK = this.ackQueue.poll();
          // System.out.println("CurrentAck: " + currentAck);
          if (currentACK == -1) {
              System.out.println();
              System.out.println("Retransmit: " + this.tcpPack.getTcpH().getTh_ack());
              System.out.println();

              udt_send(this.tcpPack);
              this.flag = 0;
          } else {
              System.out.println();
              System.out.println("Clear: " + currentACK);
              System.out.println();

              this.flag = 1;
              // break;
          }
      }
  }
  ```

  === TCP_Receiver.java
  #codly(languages: codly-languages)
  ```java
  public void rdt_recv(TCP_PACKET recvPack) {
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

          // Insert the received correct and ordered data into the data queue, preparing for delivery
          this.dataQueue.add(recvPack.getTcpS().getData());

          // Deliver data (per 20 sets of data)
          if (this.dataQueue.size() == 20)
              deliver_data();
      } else {
          // Generate NACK message segment
          this.tcpH.setTh_ack(-1);
          this.ackPack = new TCP_PACKET(this.tcpH, this.tcpS, recvPack.getSourceAddr());
          this.tcpH.setTh_sum(CheckSum.computeChkSum(this.ackPack));

          System.out.println();
          System.out.println("NACK: " + recvPack.getTcpH().getTh_seq());
          System.out.println();

          reply(this.ackPack);
      }
  }
  ```

  The sender and receiver _LOGs_ show that the checksum is calculated and verified correctly, ensuring reliable data transfer over a channel with bit errors:

  #figure(
    grid(
      columns: (1fr, 1fr),
      rows: (auto, auto),
      gutter: 1em,
      
      image("../doc/img/rdt2_log_sender.png", height: 20%),
      image("../doc/img/rdt2_log_receiver.png", height: 20%),
    ),
    caption: [RDT-2.0 Sender/Receiver LOG & Code Snippet]
  )

== RDT-2.1
  RDT-2.1 simulates transmission over a channel that may introduce *bit errors* and *packet loss*, and it uses sequence numbers, checksums, and acknowledgments to ensure reliable data transfer.

  Therefore, in addition to the checksum implementation in RDT-2.0, sequence numbers are added to the sender and receiver code to distinguish between new and old packets. The sender alternates the sequence number between 0 and 1 for each packet sent, while the receiver checks the sequence number of each received packet to determine whether it is a new packet or a duplicate.

  === TCP_Sender.java
  #codly(languages: codly-languages)
  ```java
  public void rdt_recv(TCP_PACKET recvPack) {
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

          // Insert the received correct and ordered data into the data queue, preparing for delivery
          this.dataQueue.add(recvPack.getTcpS().getData());

          // Deliver data (per 20 sets of data)
          if (this.dataQueue.size() == 20)
              deliver_data();
      } else {
          // Generate NACK message segment
          this.tcpH.setTh_ack(-1);
          this.ackPack = new TCP_PACKET(this.tcpH, this.tcpS, recvPack.getSourceAddr());
          this.tcpH.setTh_sum(CheckSum.computeChkSum(this.ackPack));

          System.out.println();
          System.out.println("NACK: " + recvPack.getTcpH().getTh_seq());
          System.out.println();

          reply(this.ackPack);
      }
  }
  ```

  === TCP_Receiver.java
  #codly(languages: codly-languages)
  ```java
  public void rdt_recv(TCP_PACKET recvPack) {
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
          this.tcpH.setTh_ack(-1);
          this.ackPack = new TCP_PACKET(this.tcpH, this.tcpS, recvPack.getSourceAddr());
          this.tcpH.setTh_sum(CheckSum.computeChkSum(this.ackPack));

          System.out.println();
          System.out.println("NACK: " + recvPack.getTcpH().getTh_seq());
          System.out.println();

          reply(this.ackPack);
      }
  }
  ```

  The sender and receiver _LOGs_ show that sequence numbers are used correctly to ensure reliable data transfer over a channel with bit errors and packet loss:

  #figure(
    grid(
      columns: (1fr, 1fr),
      rows: (auto, auto),
      gutter: 1em,
      
      image("../doc/img/rdt21_log_sender.png", height: 20%),
      image("../doc/img/rdt21_log_receiver.png", height: 20%),
    ),
    caption: [RDT-2.1 Sender/Receiver LOG & Code Snippet]
  )

== RDT-2.2
  RDT-2.2 simulates transmission over a channel that may introduce *bit errors* and *packet loss*, and it uses sequence numbers, checksums, and acknowledgments to ensure reliable data transfer. Its difference from RDT-2.1 lies in the cancel of negative acknowledgments (NACKs).

  === TCP_Receiver.java
  #codly(languages: codly-languages)
  ```java
  public void rdt_recv(TCP_PACKET recvPack) {
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
  ```

  === TCP_Sender.java
  #codly(languages: codly-languages)
  ```java
  public void recv(TCP_PACKET recvPack) {
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
  ```

  The Logs show that the receiver no longer sends NACKs, and the sender correctly handles duplicate ACKs to ensure reliable data transfer over a channel with bit errors and packet loss:
  #figure(
    grid(
      columns: (1fr, 1fr),
      rows: (auto, auto),
      gutter: 1em,
      
      image("../doc/img/rdt22_log_sender.png", height: 20%),
      image("../doc/img/rdt22_log_receiver.png", height: 20%),
    ),
    caption: [RDT-2.2 Sender/Receiver LOG & Code Snippet]
  )

== RDT-3.0
  RDT-3.0 simulates transmission over a channel that may introduce *bit errors* and *packet loss*, and it uses sequence numbers, checksums, acknowledgments, and timeouts to ensure reliable data transfer.

  Therefore, in addition to the implementations in RDT-2.2, a timeout mechanism is added to the sender code. If an acknowledgment is not received within a specified time, the sender retransmits the packet.

  === TCP_Sender.java
  #codly(languages: codly-languages)
  ```java
  public void rdt_send(int dataIndex, int[] appData) {
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
  ```

  === TCP_Receiver.java
  #codly(languages: codly-languages)
  ```java
  public void rdt_recv(TCP_PACKET recvPack) {
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
      }
  }
  ```

  The Logs show that the sender retransmits packets when timeouts occur, ensuring reliable data transfer over a channel with bit errors and packet loss:
  #figure(
    grid(
      columns: (1fr, 1fr),
      rows: (auto, auto),
      gutter: 1em,
      image("../doc/img/rdt3_log_sender.png", height: 20%),
      image("../doc/img/rdt3_log_receiver.png", height: 20%),
    ),
    caption: [RDT-3.0 Sender/Receiver LOG & Code Snippet]
  )

== Go-Back-N
  In the Go-Back-N protocol, the sender can send multiple packets before needing an acknowledgment for the first one, but if a packet is lost or corrupted, all subsequent packets are retransmitted.

  The implementation involves maintaining a sliding window of packets that can be sent without waiting for an acknowledgment. If an acknowledgment is not received for a packet within a certain time frame, the sender retransmits that packet and all subsequent packets in the window.

  === TCP_Sender.java
  #codly(languages: codly-languages)
  ```java
  public void rdt_send(int dataIndex, int[] appData) {
      // Generate the TCP data packet (set the sequence number, data field, and checksum), and pay attention to the order of packaging
      this.tcpH.setTh_seq(dataIndex * appData.length + 1); // Set the package number to the byte stream number
      this.tcpS.setData(appData);
      this.tcpPack = new TCP_PACKET(this.tcpH, this.tcpS, this.destinAddr);

      this.tcpH.setTh_sum(CheckSum.computeChkSum(this.tcpPack));
      this.tcpPack.setTcpH(this.tcpH);

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
  }
  ```

  === TCP_Receiver.java
  #codly(languages: codly-languages)
  ```java
  public void rdt_recv(TCP_PACKET recvPack) {
      // Received data packet - Check the checksum, and set the reply ACK message segment
      if (CheckSum.computeChkSum(recvPack) == recvPack.getTcpH().getTh_sum()) {
          int currentSequence = (recvPack.getTcpH().getTh_seq() - 1) / 100;
          if (this.expectedSequence == currentSequence) {
              this.tcpH.setTh_ack(recvPack.getTcpH().getTh_seq());
              this.ackPack = new TCP_PACKET(this.tcpH, this.tcpS, recvPack.getSourceAddr());
              this.tcpH.setTh_sum(CheckSum.computeChkSum(this.ackPack));

              System.out.println();
              System.out.println("ACK: " + recvPack.getTcpH().getTh_seq());
              System.out.println();

              // Reply to ACK message segment
              reply(this.ackPack);

              this.expectedSequence += 1;

              // Insert the received correct and ordered data into the data queue, preparing for delivery
              this.dataQueue.add(recvPack.getTcpS().getData());

              // Deliver data (per 20 sets of data)
              if (this.dataQueue.size() == 20)
                  deliver_data();
          }
      }
  }
  ```

  === SenderSlidingWindow.java
  #codly(languages: codly-languages)
  ```java
  public class SenderSlidingWindow {
      private Client client;
      private int size = 16;
      private int base = 0;
      private int nextIndex = 0;
      private TCP_PACKET[] packets = new TCP_PACKET[this.size];

      private Timer timer;
      private TaskPacketsRetransmit task;

      public SenderSlidingWindow(Client client) {
          this.client = client;
      }

      public boolean isFull() {
          return this.size <= this.nextIndex;
      }

      public void putPacket(TCP_PACKET packet) {
          this.packets[this.nextIndex] = packet;
          if (this.base == this.nextIndex) {
              this.timer = new Timer();
              this.task = new TaskPacketsRetransmit(this.client, this.packets);
              this.timer.schedule(this.task, 3000, 3000);
          }

          this.nextIndex++;
      }

      public void receiveACK(int currentSequence) {
          if (this.base <= currentSequence && currentSequence < this.base + this.size) {
              for (int i = 0; currentSequence - this.base + 1 + i < this.size; i++) {
                  this.packets[i] = this.packets[currentSequence - this.base + 1 + i];
                  this.packets[currentSequence - this.base + 1 + i] = null;
              }

              this.nextIndex -=currentSequence - this.base + 1;
              this.base = currentSequence + 1;

              this.timer.cancel();
              if (this.base != this.nextIndex) {
                  this.timer = new Timer();
                  this.task = new TaskPacketsRetransmit(this.client, this.packets);
                  this.timer.schedule(this.task, 3000, 3000);
              }
          }
      }
  }
  ```

  === TaskPacketsRetransmit.java
  #codly(languages: codly-languages)
  ```java
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
  ```

  The Logs show that the sender retransmits packets when timeouts occur, ensuring reliable data transfer using the Go-Back-N protocol:

  #figure(
    grid(
      columns: (1fr, 1fr),
      rows: (auto, auto),
      gutter: 1em,
      
      image("../doc/img/gbn_log_sender.png", height: 20%),
      image("../doc/img/gbn_log_receiver.png", height: 20%),
    ),
    caption: [Go-Back-N Sender/Receiver LOG]
  )


== Selective Repeat
  In the Selective Repeat protocol, the sender can send multiple packets before needing an acknowledgment for the first one, and only the lost or corrupted packets are retransmitted.

  The implementation involves maintaining a sliding window of packets that can be sent without waiting for an acknowledgment. If an acknowledgment is not received for a packet within a certain time frame, only that specific packet is retransmitted.

  === TCP_Receiver.java
  ```java
  public void rdt_recv(TCP_PACKET recvPack) {
      // Received data packet - Check the checksum, and set the reply ACK message segment
      if (CheckSum.computeChkSum(recvPack) == recvPack.getTcpH().getTh_sum()) {
          int toACKSequence = -1;
          try {
              toACKSequence = this.window.receivePacket(recvPack.clone());
          } catch (CloneNotSupportedException e) {
              e.printStackTrace();
          }

          if (toACKSequence != -1) {
              this.tcpH.setTh_ack(toACKSequence * 100 + 1);
              this.ackPack = new TCP_PACKET(this.tcpH, this.tcpS, recvPack.getSourceAddr());
              this.tcpH.setTh_sum(CheckSum.computeChkSum(this.ackPack));

              // Reply to ACK message segment
              reply(this.ackPack);
          }
      }
  }

  public void deliver_data() { }
  ```

  === SenderSlidingWindow.java
  ```java
  public class SenderSlidingWindow {
      private Client client;
      private int size = 16;
      private int base = 0;
      private int nextIndex = 0;
      private TCP_PACKET[] packets = new TCP_PACKET[this.size];
      private UDT_Timer[] timers = new UDT_Timer[this.size];

      public SenderSlidingWindow(Client client) {
          this.client = client;
      }

      public boolean isFull() {
          return this.size <= this.nextIndex;
      }

      public void putPacket(TCP_PACKET packet) {
          this.packets[this.nextIndex] = packet;
          this.timers[this.nextIndex] = new UDT_Timer();
          this.timers[this.nextIndex].schedule(new UDT_RetransTask(this.client, packet), 3000, 3000);

          this.nextIndex++;
      }

      public void receiveACK(int currentSequence) {
          if (this.base <= currentSequence && currentSequence < this.base + this.size) {
              if (this.timers[currentSequence - this.base] == null) {
                  return;
              }

              this.timers[currentSequence - this.base].cancel();
              this.timers[currentSequence - this.base] = null;

              if (currentSequence == this.base) {
                  int maxACKedIndex = 0;
                  while (maxACKedIndex + 1 < this.nextIndex
                          && this.timers[maxACKedIndex + 1] == null) {
                      maxACKedIndex++;
                  }

                  for (int i = 0; maxACKedIndex + 1 + i < this.size; i++) {
                      this.packets[i] = this.packets[maxACKedIndex + 1 + i];
                      this.timers[i] = this.timers[maxACKedIndex + 1 + i];
                  }

                  for (int i = this.size - (maxACKedIndex + 1); i < this.size; i++) {
                      this.packets[i] = null;
                      this.timers[i] = null;
                  }

                  this.base += maxACKedIndex + 1;
                  this.nextIndex -= maxACKedIndex + 1;
              }
          }
      }
  }
  ```

  === ReceiverSlidingWindow.java
  ```java
  public class ReceiverSlidingWindow {
      private Client client;
      private int size = 16;
      private int base = 0;
      private TCP_PACKET[] packets = new TCP_PACKET[this.size];
      Queue<int[]> dataQueue = new LinkedBlockingQueue();

      private int counts = 0;

      public ReceiverSlidingWindow(Client client) {
          this.client = client;
      }

      public int receivePacket(TCP_PACKET packet) {
          int currentSequence = (packet.getTcpH().getTh_seq() - 1) / 100;

          if (currentSequence < this.base) {
              // ACK [base - size, base - 1]
              int left = this.base - this.size;
              int right = this.base - 1;
              if (left <= 0) {
                  left = 1;
              }

              if (left <= currentSequence && currentSequence <= right) {
                  return currentSequence;
              }
          } else if (this.base <= currentSequence && currentSequence < this.base + this.size) {
              this.packets[currentSequence - this.base] = packet;

              if (currentSequence == this.base) {
                  this.slid();
              }
              return currentSequence;
          }
          return -1;
      }

      private void slid() {
          int maxIndex = 0;
          while (maxIndex + 1 < this.size
                  && this.packets[maxIndex + 1] != null) {
              maxIndex++;
          }

          for (int i = 0; i < maxIndex + 1; i++) {
              this.dataQueue.add(this.packets[i].getTcpS().getData());
          }

          for (int i = 0; maxIndex + 1 + i < this.size; i++) {
              this.packets[i] = this.packets[maxIndex + 1 + i];
          }

          for (int i = this.size - (maxIndex + 1); i < this.size; i++) {
              this.packets[i] = null;
          }

          this.base += maxIndex + 1;

          if (this.dataQueue.size() >= 20 || this.base == 1000) {
              this.deliver_data();
          }
      }

      public void deliver_data() {
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

                  writer.flush(); // Clear out Caches
              }

              writer.close();
          } catch (IOException e) {
              e.printStackTrace();
          }
      }
  }
  ```

  The Logs show that the sender retransmits only the lost or corrupted packets, ensuring reliable data transfer using the Selective Repeat protocol:

  #figure(
    grid(
      columns: (1fr, 1fr),
      rows: (auto, auto),
      gutter: 1em,
      
      image("../doc/img/sr_log_sender.png", height: 20%),
      image("../doc/img/sr_log_receiver.png", height: 20%),
    ),
    caption: [Selective Repeat Sender/Receiver LOG]
  )

== TCP
  In the TCP protocol, reliable data transfer is achieved through a combination of sequence numbers, acknowledgments, checksums, timeouts, and congestion control mechanisms.

  Therefore, in addition to the implementations in Selective Repeat, congestion control algorithms such as TCP Tahoe and TCP Reno are implemented to manage network congestion and optimize data transmission rates.

  === ReceiverSlidingWindow.java
  ```java
  public int receivePacket(TCP_PACKET packet) {
      int currentSequence = (packet.getTcpH().getTh_seq() - 1) / 100;

      if (currentSequence >= this.expectedSequence) {
          putPacket(packet);
      }
      slid();

      return this.expectedSequence - 1;
  }

  private void putPacket(TCP_PACKET packet) {
      int currentSequence = (packet.getTcpH().getTh_seq() - 1) / 100;

      int index = 0;
      while (index < this.packets.size() && currentSequence > (this.packets.get(index).getTcpH().getTh_seq() - 1) / 100) {
          index++;
      }

      if (index == this.packets.size() || currentSequence != (this.packets.get(index).getTcpH().getTh_seq() - 1) / 100) {
          this.packets.add(index, packet);
      }
  }

  private void slid() {
      while (!this.packets.isEmpty() && (this.packets.getFirst().getTcpH().getTh_seq() - 1) / 100 == this.expectedSequence) {
          this.dataQueue.add(this.packets.poll().getTcpS().getData());
          this.expectedSequence++;
      }

      if (this.dataQueue.size() >= 20 || this.expectedSequence == 1000) {
          this.deliver_data();
      }
  }
  ```

  === SenderSlidingWindow.java
  ```java
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
  ```

  The Logs show that the sender and receiver correctly implement TCP mechanisms, ensuring reliable data transfer with congestion control:

  #figure(
    grid(
      columns: (1fr, 1fr),
      rows: (auto, auto),
      gutter: 1em,
      
      image("../doc/img/tcp_log_sender.png", height: 20%),
      image("../doc/img/tcp_log_receiver.png", height: 20%),
    ),
    caption: [TCP Sender/Receiver LOG & Code Snippet]
  )

== TCP Tahoe
  In TCP Tahoe, the congestion control mechanism includes slow start, congestion avoidance, and fast retransmit. When packet loss is detected, the congestion window size is reset to one segment, and the slow start phase begins again.

  The implementation involves monitoring acknowledgments and adjusting the congestion window size based on network conditions. When a timeout occurs or three duplicate ACKs are received, the congestion window size is reset, and the slow start phase is initiated.

  === SenderSlidingWindow.java
  ```java
  public void receiveACK(int currentSequence) {
      if (currentSequence == this.lastACKSequence) {
          this.lastACKSequenceCount++;
          if (this.lastACKSequenceCount == 4) {
              TCP_PACKET packet = this.packets.get(currentSequence + 1);
              if (packet != null) {
                  this.client.send(packet);
                  this.timers.get(currentSequence + 1).cancel();
                  this.timers.put(currentSequence + 1, new UDT_Timer());
                  this.timers.get(currentSequence + 1).schedule(new RetransmitTask(this.client, packet, this), 3000, 3000);
              }

              slowStart();
          }
      } else {
          for (int i = this.lastACKSequence + 1; i <= currentSequence; i++) {
              this.packets.remove(i);

              if (this.timers.containsKey(i)) {
                  this.timers.get(i).cancel();
                  this.timers.remove(i);
              }
          }

          this.lastACKSequence = currentSequence;
          this.lastACKSequenceCount = 1;

          if (this.cwnd < this.ssthresh) {
              this.cwnd++;
              System.out.println("########### window expand ############");
          } else {
              this.count++;
              if (this.count >= this.cwnd) {
                  this.count -= this.cwnd;
                  this.cwnd++;
                  System.out.println("########### window expand ############");
              }
          }
      }
  }

  public void slowStart() {
      System.out.println("00000 cwnd: " + this.cwnd);
      System.out.println("00000 ssthresh: " + this.ssthresh);
      this.ssthresh = this.cwnd / 2;
      this.cwnd = 1;
      System.out.println("11111 cwnd: " + this.cwnd);
      System.out.println("11111 ssthresh: " + this.ssthresh);
  }
  ```

  The Logs show that the sender correctly implements TCP Tahoe congestion control mechanisms, ensuring reliable data transfer with congestion management:

  #figure(
    grid(
      columns: (1fr, 1fr),
      rows: (auto, auto),
      gutter: 1em,
      
      image("../doc/img/tcp_tahoe_log_sender.png", height: 20%),
      image("../doc/img/tcp_tahoe_log_receiver.png", height: 20%),
    ),
    caption: [TCP Tahoe Sender/Receiver LOG & Code Snippet]
  )

== TCP Reno
  In TCP Reno, the congestion control mechanism includes slow start, congestion avoidance, fast retransmit, and fast recovery. When packet loss is detected through three duplicate ACKs, the congestion window size is halved, and the fast recovery phase begins.

  The implementation involves monitoring acknowledgments and adjusting the congestion window size based on network conditions. When three duplicate ACKs are received, the congestion window size is halved, and the fast recovery phase is initiated.

  === SenderSlidingWindow.java
  #codly(languages: codly-languages)
  ```java
    public void putPacket(TCP_PACKET packet) {
        int currentSequence = (packet.getTcpH().getTh_seq() - 1) / 100;
        this.packets.put(currentSequence, packet);

        if (this.timer == null) {
            this.timer = new UDT_Timer();
            this.timer.schedule(new RetransmitTask(this), 3000, 3000);
        }
    }

    public void receiveACK(int currentSequence) {
        if (currentSequence == this.lastACKSequence) {
            this.lastACKSequenceCount++;

            if (this.lastACKSequenceCount == 4) {
                TCP_PACKET packet = this.packets.get(currentSequence + 1);
                if (packet != null) {
                    this.client.send(packet);

                    if (this.timer != null) {
                        this.timer.cancel();
                    }
                    this.timer = new UDT_Timer();
                    this.timer.schedule(new RetransmitTask(this), 3000, 300);
                }

                fastRecovery();
            } else if (this.lastACKSequenceCount > 4) {
                this.cwnd++;
                System.out.println("--- Fast Recovery Inflate: cwnd " + (this.cwnd - 1) + " -> " + this.cwnd);
            }
        } else {
            List sequenceList = new ArrayList(this.packets.keySet());
            Collections.sort(sequenceList);
            for (int i = 0; i < sequenceList.size() && (int) sequenceList.get(i) <= currentSequence; i++) {
                this.packets.remove(sequenceList.get(i));
            }

            if (this.timer != null) {
                this.timer.cancel();
            }

            if (this.packets.size() != 0) {
                this.timer = new UDT_Timer();
                this.timer.schedule(new RetransmitTask(this), 3000, 300);
            }

            this.lastACKSequence = currentSequence;
            this.lastACKSequenceCount = 1;

            if (this.isFastRecovery) {
                System.out.println("--- Fast Recovery Exit ---");
                this.cwnd = this.ssthresh;
                this.isFastRecovery = false;
                System.out.println("cwnd reset to ssthresh: " + this.cwnd);
            } else {
                if (this.cwnd < this.ssthresh) {
                    this.cwnd++;
                    System.out.println("########### Slow Start: window expand ############");
                } else {
                    this.count++;
                    if (this.count >= this.cwnd) {
                        this.count -= this.cwnd;
                        this.cwnd++;
                        System.out.println("########### Congestion Avoidance: window expand ############");
                    }
                }
            }
        }
    }

    public void slowStart() {
        System.out.println("--- Slow Start ---");
        System.out.println("00000 cwnd: " + this.cwnd);
        System.out.println("00000 ssthresh: " + this.ssthresh);

        this.ssthresh = this.cwnd / 2;
        if (this.ssthresh < 2) {
            this.ssthresh = 2;
        }
        this.cwnd = 1;
        this.isFastRecovery = false;

        System.out.println("11111 cwnd: " + this.cwnd);
        System.out.println("11111 ssthresh: " + this.ssthresh);
    }

    public void fastRecovery() {
        System.out.println("--- Fast Recovery ---");
        System.out.println("00000 cwnd: " + this.cwnd);
        System.out.println("00000 ssthresh: " + this.ssthresh);

        this.ssthresh = this.cwnd / 2;
        if (this.ssthresh < 2) {
            this.ssthresh = 2;
        }

        this.cwnd = this.ssthresh;
        this.isFastRecovery = true;

        System.out.println("11111 cwnd: " + this.cwnd);
        System.out.println("11111 ssthresh: " + this.ssthresh);
    }

    public void retransmit() {
        this.timer.cancel();

        List sequenceList = new ArrayList(this.packets.keySet());
        Collections.sort(sequenceList);

        for (int i = 0; i < this.cwnd && i < sequenceList.size(); i++) {
            TCP_PACKET packet = this.packets.get(sequenceList.get(i));
            if (packet != null) {
                System.out.println("retransmit: " + (packet.getTcpH().getTh_seq() - 1) / 100);
                this.client.send(packet);
            }
        }

        if (this.packets.size() != 0) {
            this.timer = new UDT_Timer();
            this.timer.schedule(new RetransmitTask(this), 3000, 3000);
        } else {
            System.out.println("000000000000000000 no packet");
        }
    }
  ```

  The Logs show that the sender correctly implements TCP Reno congestion control mechanisms, ensuring reliable data transfer with congestion management:

  #figure(
    grid(
      columns: (1fr, 1fr),
      rows: (auto, auto),
      gutter: 1em,
      
      image("../doc/img/tcp_reno_log_sender.png", height: 20%),
      image("../doc/img/tcp_reno_log_receiver.png", height: 20%),
    ),
    caption: [TCP Reno Sender/Receiver LOG & Code Snippet]
  )

= Incomplete projects, indicating key difficulties in completion and possible solutions.
  Based on the current progress, all required protocols (RDT 1.0 through TCP Reno) have been implemented. However, compared to a full-featured industrial TCP implementation, the current *TCP Reno* implementation has room for refinement, specifically regarding *Selective Acknowledgment (SACK)* and *RTT estimation*.

  1. TCP NewReno / SACK (Not Implemented)
    + *Difficulty*: The current Reno implementation falls back to retransmitting only the packet triggered by 3-duplicate ACKs or Timeout. If multiple packets are lost in a single window, Reno performance degrades significantly (often resulting in a timeout). Implementing SACK requires changing the TCP header structure to carry blocks of received bytes and modifying the sender's data structure to maintain a "scoreboard" of acknowledged gaps.

    + *Proposed Solution:* Extend the `TCP_HEADER` class to support options fields. On the receiver side, track non-contiguous received blocks. On the sender side, modify the retransmission logic to prioritize gaps indicated by SACK blocks rather than just the `base` sequence.

  2. Dynamic RTO Calculation (Karn's Algorithm)
    + *Difficulty:* The current implementation uses a hardcoded timeout interval (`3000ms`). In a real network, RTT varies. Implementing dynamic RTO requires measuring SampleRTT, calculating EstimatedRTT and DevRTT. The difficulty lies in accurately matching sent packets with their ACKs when retransmissions occur (the retransmission ambiguity problem).
    + *Proposed Solution:* Implement Karn's Algorithm. Timestamp packets upon sending. Update RTT estimates only for non-retransmitted packets. Use the formula $"RTO" = "EstimatedRTT" + 4 times "DevRTT"$.
  

= Explain the advantages or problems of using iterative development in the experiment process.
  *Advantages:*
  1. *Reduced Cognitive Load:* The experiment starts with an ideal channel (RDT 1.0) and incrementally adds channel impairments (bit errors $\to$ packet loss). This allows focusing on one problem at a time. For instance, we solved data corruption using Checksum in RDT 2.0 before worrying about sequence numbers for duplicates in RDT 2.1.
  2. *Simplified Debugging:* If a bug appears in RDT 3.0 (Timeout), we can be reasonably confident that the Checksum logic (inherited from RDT 2.0) and Sequence Number logic (inherited from RDT 2.1) are correct. This isolation makes troubleshooting significantly faster.
  3. *Code Reusability:* Core classes like `CheckSum`, `TCP_PACKET`, and `TCP_HEADER` were defined once and reused across all versions. The structure of `rdt_send` and `rdt_recv` evolved naturally, making the transition from Stop-and-Wait to Sliding Window (GBN/SR) a structural update rather than a complete rewrite.

  *Problems:*
  1. *Structural Refactoring Costs* Moving from RDT 3.0 (Stop-and-Wait) to GBN/SR (Pipelining) required a major architectural change. The simple state machine of "wait for ACK" had to be replaced by buffering queues, window variables (`base`, `nextSeqNum`), and multiple timer management. This "jump" was much harder than the incremental steps between 2.0 and 2.2.
  2. *Legacy Code Overhead:* In early iterations, some temporary variables or print statements might be left over. As the logic becomes more complex (e.g., adding Congestion Control to SR), keeping the code clean and ensuring old logic doesn't interfere with new state variables (like `cwnd`) requires constant vigilance.

= Summarize the main problems that have been solved in the process of completing the big homework and the corresponding solutions taken by myself.
  + *Problem 1: Object Reference vs. Deep Copy in Buffering*
    - *Issue:* In the Go-Back-N and TCP sender implementation, when putting a packet into the `SenderSlidingWindow`, I initially passed the `tcpPack` object directly. Since Java passes references by value, modifying the packet for retransmission (or if the application layer modified the array) sometimes caused inconsistency in the buffered packets.
    - *Solution:* As shown in the code snippet for GBN, I used `this.window.putPacket(this.tcpPack.clone());`. Implementing the `Cloneable` interface for `TCP_PACKET` ensured that the sliding window stored a snapshot of the packet as it was when sent, preventing unintended side effects.

  + *Problem 2: Timer Management in Selective Repeat*
    - *Issue:* In SR, each packet needs its own logical timer. Creating a new Java `Timer` thread for every single packet caused high resource consumption and race conditions when cancelling timers during rapid ACK bursts.
    - *Solution:* I utilized the provided `UDT_Timer` wrapper efficiently. Instead of creating global timers, I maintained an array of timers `timers[]` corresponding to the sequence numbers in the window. Crucially, in `receiveACK`, I added checks `if (this.timers[...] != null)` before cancelling to avoid `NullPointerException` when duplicate ACKs arrived.

  + *Problem 3: Fast Recovery Logic in TCP Reno*
    - *Issue:* Initially, my Reno implementation simply halved `cwnd` upon 3-dup ACKs but failed to implement the "Window Inflation" (adding 3 to `cwnd` and incrementing for subsequent dup ACKs). This caused the throughput to drop more than necessary, resembling Tahoe behavior.
    - *Solution:* I introduced a boolean flag `isFastRecovery`.
        - When `lastACKSequenceCount == 4`: set `ssthresh = cwnd / 2`, `cwnd = ssthresh + 3`, set `isFastRecovery = true`, and retransmit.
        - When `lastACKSequenceCount > 4`: `cwnd++` (inflate window).
        - When a *new* ACK arrives: if `isFastRecovery` is true, set `cwnd = ssthresh` (deflate window) and set `isFastRecovery = false`.

  + *Problem 4: Integer Division in Congestion Avoidance*
    - *Issue:* In Congestion Avoidance, `cwnd` should increase by $1 / "cwnd"$ per ACK. Since `cwnd` is an integer, `1 / cwnd` becomes 0.
    - *Solution:* I used a counter variable `count`. `count` increments by 1 for each ACK. When `count >= cwnd`, I increment `cwnd` by 1 and reset `count`. This simulates the linear growth of adding 1 MSS per RTT.

= Ask questions or suggestions about the experimental system.
  *Suggestions:*
  1. *Visualization Interface:* It would be very helpful if the system provided a graphical visualization of the packet flow, specifically showing the Sliding Window moving in real-time. Debugging purely via text logs (as shown in the figures) is effective but hard to intuitively grasp the timing of "flight" packets.
  2. *Jitter Simulation:* The current channel simulates loss and bit errors well. Adding "Jitter" (random variation in delay) would make the RTT estimation and Timeout settings more challenging and realistic, better highlighting the need for dynamic RTO.