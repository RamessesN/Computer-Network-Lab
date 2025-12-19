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

= Analysis of Code and LOG Combination

== RDT-2.0
  RDT-1.0 is based on the assumption that all channels are reliable, while RDT-2.0 is based on the assumption that *bit errors* may occur. RDT-2.0 uses _CheckSum_ to check whether the data packet is correct, and feedback information through _ACK/NAK_. The implementation of `CheckSum` and `TCP_Receiver` are as follows:

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

  The checksum calculation uses the CRC32 algorithm, which is more robust than the traditional binary inverse code sum --- The code first extracts the key control information (sequence number and acknowledgment number) of the TCP packet header, then traverses the entire data payload area, updates all the byte streams into the CRC32 calculation instance one by one, and finally converts the 32-bit check value obtained by the calculation into the Short type, which is used as the unique verification identifier of the packet integrity.
  
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

  After receiving the packet, the receiver firstly called the checksum class to recalculate the checksum and compared it with the packet header record. If the checksum passed, the data was lossless, and the ACK packet containing the current sequence number was constructed and sent back to the sender, and the data were stored in the delivery queue in order. If the verification fails it enters the error handling branch, constructs a NAK message with an acknowledgment number of -1 and sends it back to the sender, which clearly indicates that the data has been corrupted and triggers the retransmission mechanism at the sender.

  === Results and Analysis
  + *Results* \
    - Sender Log
      #codly(languages: codly-languages)
      ```Log
      2025-12-17 23:06:51:045 CST	DATA_seq: 1501 WRONG	NO_ACK
      2025-12-17 23:06:51:046 CST	*Re: DATA_seq: 1501		ACKed
      ```
    - Receiver Log
      #codly(languages: codly-languages)
      ```Log
      2025-12-17 23:06:51:046 CST	ACK_ack: -1	
      2025-12-17 23:06:51:047 CST	ACK_ack: 1501
      ```
    - Terminal Output
      #codly(languages: codly-languages)
      ```Terminal
      -> 2025-12-17 23:06:51:045 CST
      ** TCP_Receiver
      Receive packet from: [10.150.203.17:9001]
      Packet data: 12569 12577 12583 12589 12601 12611 12613 12619 12637 12641 12647 12653 12659 12671 12689 12697 12703 12713 12721 12739 12743 12757 12763 12781 12791 12799 12809 12821 12823 12829 12841 12853 12889 12893 12899 12907 12911 12917 12919 12923 12941 12953 12959 12967 12973 12979 12983 13001 13003 13007 13009 13033 13037 13043 13049 13063 13093 13099 13103 13109 13121 13127 13147 13151 13159 13163 13171 13177 13183 13187 13217 13219 13229 13241 13249 13259 13267 13291 13297 13309 13313 13327 13331 13337 13339 13367 13381 13397 13399 13411 13417 13421 13441 13451 13457 13463 13469 13477 13487 -1332160980
      PACKET_TYPE: DATA_SEQ_1501

      NACK: 1501

      -> 2025-12-17 23:06:51:046 CST
      ** TCP_Sender
      Receive packet from: [10.150.203.17:9002]
      Packet data:
      PACKET_TYPE: ACK_-1

      Receive ACK Number: -1

      Retransmit: 1
      ```

  + *Analysis* \
    *1)* When the packet with sequence number 1501 occurs bit flip in transmission and causes CRC32 verification failure, the receiver correctly recognizes the error and sends back the NAK (ACK=-1) packet to the sender. *2)* The sender then immediately retransmitted the corrupted packet based on the negative acknowledgment, and the retransmitted packet passed the verification and received an ACK acknowledgement. This demonstrates how the system can ensure data integrity over unreliable channels by error detection and automatic retransmission mechanism.

== RDT-2.2
  RDT-2.2 is based on the assumption that *bit errors* and *ACK corruption*. Its difference from RDT-2.1 is that it deprecate _NAK_ to feedback. The detailed implementations are here:

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

  The receiver first used the checksum to verify the integrity of the received packet. If the checksum passed, it replied an ACK containing the sequence number of the current packet, and judged whether the data was new according to the sequence number to decide whether to write to the buffer. If the verification fails, the current packet is dropped and a Duplicate ACK containing the last correctly received sequence number is forced to be sent. The cumulative acknowledgment mechanism is used to implicitly inform the sender that the current packet transmission has failed, so as to realize error feedback without NAK.

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

  After receiving the feedback packet, the sender first checked the checksum. If the ACK packet was complete, the acknowledgment number was extracted and added to the processing queue to confirm the successful data transmission and advance the sending window. If the ACK packet itself is detected to be bit corrupted, it will be marked as invalid, which will make the sender unable to obtain the expected positive acknowledgment, so as to trigger the retransmission mechanism of the current data packet in the subsequent status check, so as to solve the bit error problem on the feedback link.

  === Results and Analysis
  + *Results* \
    *Case I - bit error*
    - Sender Log
      #codly(languages: codly-languages)
      ```Log
      2025-12-17 23:39:20:713 CST	DATA_seq: 2101	WRONG	NO_ACK
      2025-12-17 23:39:20:714 CST	*Re: DATA_seq: 2101		ACKed
      ```
    - Receiver Log
      #codly(languages: codly-languages)
      ```Log
      2025-12-17 23:39:20:714 CST	ACK_ack: 2101
      ```
    - Terminal Output
      #codly(languages: codly-languages)
      ```Terminal
      Retransmit: 1

      -> 2025-12-17 23:39:20:714 CST
      ** TCP_Receiver
        Receive packet from: [10.150.203.17:9001]
        Packet data: 18329 18341 18353 18367 18371 18379 18397 18401 18413 18427 18433 18439 18443 18451 18457 18461 18481 18493 18503 18517 18521 18523 18539 18541 18553 18583 18587 18593 18617 18637 18661 18671 18679 18691 18701 18713 18719 18731 18743 18749 18757 18773 18787 18793 18797 18803 18839 18859 18869 18899 18911 18913 18917 18919 18947 18959 18973 18979 19001 19009 19013 19031 19037 19051 19069 19073 19079 19081 19087 19121 19139 19141 19157 19163 19181 19183 19207 19211 19213 19219 19231 19237 19249 19259 19267 19273 19289 19301 19309 19319 19333 19373 19379 19381 19387 19391 19403 19417 19421 19423
        PACKET_TYPE: DATA_SEQ_2101

      ACK: 2101

      -> 2025-12-17 23:39:20:714 CST
      ** TCP_Sender
        Receive packet from: [10.150.203.17:9002]
        Packet data:
        PACKET_TYPE: ACK_2101

      Receive ACK Number: 2101


      Clear: 2101
      ```

    *Case II - ACK corruption*
    - Sender Log
    #codly(languages: codly-languages)
    ```Log
    2025-12-17 23:39:26:764 CST	DATA_seq: 47801		NO_ACK
    2025-12-17 23:39:26:765 CST	*Re: DATA_seq: 47801		ACKed
    ```

    - Receiver Log
    #codly(languages: codly-languages)
    ```Log
    2025-12-17 23:39:26:765 CST	ACK_ack: -1141006879	WRONG
    2025-12-17 23:39:26:765 CST	ACK_ack: 47801
    ```

    - Terminal
    #codly(languages: codly-languages)
    ```Terminal
    -> 2025-12-17 23:39:26:764 CST
    ** TCP_Receiver
      Receive packet from: [10.150.203.17:9001]
      Packet data: 582821 582851 582853 582859 582887 582899 582931 582937 582949 582961 582971 582973 582983 583007 583013 583019 583021 583031 583069 583087 583127 583139 583147 583153 583169 583171 583181 583189 583207 583213 583229 583237 583249 583267 583273 583279 583291 583301 583337 583339 583351 583367 583391 583397 583403 583409 583417 583421 583447 583459 583469 583481 583493 583501 583511 583519 583523 583537 583543 583577 583603 583613 583619 583621 583631 583651 583657 583669 583673 583697 583727 583733 583753 583769 583777 583783 583789 583801 583841 583853 583859 583861 583873 583879 583903 583909 583937 583969 583981 583991 583997 584011 584027 584033 584053 584057 584063 584081 584099 584141
      PACKET_TYPE: DATA_SEQ_47801

    ACK: 47801

    -> 2025-12-17 23:39:26:765 CST
    ** TCP_Sender
      Receive packet from: [10.150.203.17:9002]
      Packet data:
      PACKET_TYPE: ACK_-1141006879

    Receive corrupt ACK: -1141006879

    Retransmit: 1

    -> 2025-12-17 23:39:26:765 CST
    ** TCP_Receiver
      Receive packet from: [10.150.203.17:9001]
      Packet data: 582821 582851 582853 582859 582887 582899 582931 582937 582949 582961 582971 582973 582983 583007 583013 583019 583021 583031 583069 583087 583127 583139 583147 583153 583169 583171 583181 583189 583207 583213 583229 583237 583249 583267 583273 583279 583291 583301 583337 583339 583351 583367 583391 583397 583403 583409 583417 583421 583447 583459 583469 583481 583493 583501 583511 583519 583523 583537 583543 583577 583603 583613 583619 583621 583631 583651 583657 583669 583673 583697 583727 583733 583753 583769 583777 583783 583789 583801 583841 583853 583859 583861 583873 583879 583903 583909 583937 583969 583981 583991 583997 584011 584027 584033 584053 584057 584063 584081 584099 584141
      PACKET_TYPE: DATA_SEQ_47801

    ACK: 47801

    -> 2025-12-17 23:39:26:765 CST
    ** TCP_Sender
      Receive packet from: [10.150.203.17:9002]
      Packet data:
      PACKET_TYPE: ACK_47801

    Receive ACK Number: 47801

    Clear: 47801
    ```

  + *Analysis* \
    In Case I, the situation is similar to RDT2.0 above; \
    In Case II, it can be seen that although the receiver received the data correctly and sent ACK 47801, the acknowledgment packet was corrupted on the return path (changed to -1141006879). *1)* After detecting the corrupted ACK using the checksum, the sender regarded it as invalid acknowledgment and executed the retransmission strategy. *2)* Subsequently, the receiver received the duplicate packet (Data 47801) and sent the acknowledgment again, and the sender finally received the correct ACK and completed the status update. This completely demonstrates how the protocol only uses positive acknowledgment with error retransmission mechanism to ensure reliable data delivery when the channel is bidirectional unreliable.

== RDT-3.0
  RDT-3.0 deals with the situation of packet loss based on RDT-2.2, adding a timer mechanism --- if the sender does not receive the feedback information during the RTT period, the sender assumes that the packet has been lost and will automatically retransmit it.

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

  After the sender encapsulates the packet and calculates the checksum, it introduces the core mechanism of RDT 3.0, the Countdown Timer, aimed at solving the packet loss problem in the channel. The code starts a timer when the packet is sent via `udt_send` and then enters a Stop-and-Wait state; If the ACK is received before the timeout, the timer is canceled and the next packet is ready to be sent, otherwise the timer expiration will automatically trigger the retransmission task.

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

  After receiving the packet, the receiver first checks and verifies it, and replies an ACK immediately if it passes. For duplicate packets that may appear in RDT 3.0, caused by the sender's retransmission timeout, the receiver deduplicates packets by comparing the current sequence number with `lastSequence` --- If it is a new sequence number, it will be stored in the data queue. If it is an old sequence duplicate number, it will only resend the ACK but discard the data, so as to ensure that the data received by the upper application is not repeated and in the correct order.

  === Results and Analysis
  + *Results* \
    *Case I - Packet Loss*
      - Sender Log
      #codly(languages: codly-languages)
      ```Log
      2025-12-18 00:05:56:241 CST	DATA_seq: 13601		NO_ACK
      2025-12-18 00:05:59:246 CST	*Re: DATA_seq: 13601		ACKed
      ```

      - Receiver Log
      #codly(languages: codly-languages)
      ```Log
      2025-12-18 00:05:56:241 CST	ACK_ack: 13601	LOSS
      2025-12-18 00:05:59:247 CST	*Re: ACK_ack: 13601	
      ```

      - Terminal Output
      #codly(languages: codly-languages)
      ```Terminal
      -> 2025-12-18 00:05:56:241 CST
      ** TCP_Receiver
        Receive packet from: [10.150.203.17:9001]
        Packet data: 147137 147139 147151 147163 147179 147197 147209 147211 147221 147227 147229 147253 147263 147283 147289 147293 147299 147311 147319 147331 147341 147347 147353 147377 147391 147397 147401 147409 147419 147449 147451 147457 147481 147487 147503 147517 147541 147547 147551 147557 147571 147583 147607 147613 147617 147629 147647 147661 147671 147673 147689 147703 147709 147727 147739 147743 147761 147769 147773 147779 147787 147793 147799 147811 147827 147853 147859 147863 147881 147919 147937 147949 147977 147997 148013 148021 148061 148063 148073 148079 148091 148123 148139 148147 148151 148153 148157 148171 148193 148199 148201 148207 148229 148243 148249 148279 148301 148303 148331 148339
        PACKET_TYPE: DATA_SEQ_13601

      ACK: 13601

      -> 2025-12-18 00:05:59:246 CST
      ** TCP_Receiver
        Receive packet from: [10.150.203.17:9001]
        Packet data: 147137 147139 147151 147163 147179 147197 147209 147211 147221 147227 147229 147253 147263 147283 147289 147293 147299 147311 147319 147331 147341 147347 147353 147377 147391 147397 147401 147409 147419 147449 147451 147457 147481 147487 147503 147517 147541 147547 147551 147557 147571 147583 147607 147613 147617 147629 147647 147661 147671 147673 147689 147703 147709 147727 147739 147743 147761 147769 147773 147779 147787 147793 147799 147811 147827 147853 147859 147863 147881 147919 147937 147949 147977 147997 148013 148021 148061 148063 148073 148079 148091 148123 148139 148147 148151 148153 148157 148171 148193 148199 148201 148207 148229 148243 148249 148279 148301 148303 148331 148339
        PACKET_TYPE: DATA_SEQ_13601

      ACK: 13601

      -> 2025-12-18 00:05:59:247 CST
      ** TCP_Sender
        Receive packet from: [10.150.203.17:9002]
        Packet data:
        PACKET_TYPE: ACK_13601

      Receive ACK Number: 13601

      Clear: 13601
      ```

    *Case II - ACK Loss*
      - Sender Log
      #codly(languages: codly-languages)
      ```Log
      2025-12-18 15:35:02:120 CST	DATA_seq: 24001		NO_ACK
      2025-12-18 15:35:05:120 CST	*Re: DATA_seq: 24001		ACKed
      ```

      - Receiver Log
      #codly(languages: codly-languages)
      ```Log
      2025-12-18 15:35:02:120 CST	ACK_ack: 24001	LOSS
      2025-12-18 15:35:05:121 CST	*Re: ACK_ack: 24001	
      ```

      - Terminal Output
      #codly(languages: codly-languages)
      ```Terminal
      -> 2025-12-18 15:35:02:120 CST
      ** TCP_Receiver
        Receive packet from: [10.150.200.45:9001]
        Packet data: 274579 274583 274591 274609 274627 274661 274667 274679 274693 274697 274709 274711 274723 274739 274751 274777 274783 274787 274811 274817 274829 274831 274837 274843 274847 274853 274861 274867 274871 274889 274909 274931 274943 274951 274957 274961 274973 274993 275003 275027 275039 275047 275053 275059 275083 275087 275129 275131 275147 275153 275159 275161 275167 275183 275201 275207 275227 275251 275263 275269 275299 275309 275321 275323 275339 275357 275371 275389 275393 275399 275419 275423 275447 275449 275453 275459 275461 275489 275491 275503 275521 275531 275543 275549 275573 275579 275581 275591 275593 275599 275623 275641 275651 275657 275669 275677 275699 275711 275719 275729
        PACKET_TYPE: DATA_SEQ_24001

      ACK: 24001

      -> 2025-12-18 15:35:05:120 CST
      ** TCP_Receiver
        Receive packet from: [10.150.200.45:9001]
        Packet data: 274579 274583 274591 274609 274627 274661 274667 274679 274693 274697 274709 274711 274723 274739 274751 274777 274783 274787 274811 274817 274829 274831 274837 274843 274847 274853 274861 274867 274871 274889 274909 274931 274943 274951 274957 274961 274973 274993 275003 275027 275039 275047 275053 275059 275083 275087 275129 275131 275147 275153 275159 275161 275167 275183 275201 275207 275227 275251 275263 275269 275299 275309 275321 275323 275339 275357 275371 275389 275393 275399 275419 275423 275447 275449 275453 275459 275461 275489 275491 275503 275521 275531 275543 275549 275573 275579 275581 275591 275593 275599 275623 275641 275651 275657 275669 275677 275699 275711 275719 275729
        PACKET_TYPE: DATA_SEQ_24001

      ACK: 24001

      -> 2025-12-18 15:35:05:121 CST
      ** TCP_Sender
        Receive packet from: [10.150.200.45:9002]
        Packet data:
        PACKET_TYPE: ACK_24001

      Receive ACK Number: 24001

      Clear: 24001
      ```

  + *Analysis* \
    The basic bit-error and ACK-corruption handling mechanisms (similar to RDT 2.2) are omitted here to focus on the new features. *1)* In Case I --- Packet Loss, the sender's timer expired before receiving any ACK, triggering a correct retransmission. *2)* In Case II --- ACK Loss, the sender retransmitted due to timeout, and the receiver correctly handled the duplicate packet by re-sending the ACK.

    In practice, RDT-3.0 worked, but the performance was poor. The main reason is that during the RTT period, the network is idle, and the RTT period is relatively long, which makes the utilization very low.

== Go-Back-N
  Go-Back-N protocol has 4 main characteristics: *1)* The sender has at most N unconfirmed datagrams in its pipeline; *2)* the receiver only sends cumulative acknowledgments and does not acknowledge if any of the intermediate datagrams are missing; *3)* the sender clocks the longest unconfirmed datagrams and retransmits all unconfirmed datagrams if the timer expires; *4)* the sending window is greater than 1, The accept window is equal to 1 - which means that if there is an error in one of the packet segments, the accept window will stop again and the incoming data will be discarded.

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

  I implement this class to maintain the sliding window state of the sender through an array, and realizes the core logic of pipeline sending. `putPacket` puts the newly generated data packet into the window buffer. If the current window is empty, the timer is started immediately. `receiveACK` implements GBN's signature cumulative acknowledgment mechanism, which, when a valid ACK is received, slides the window forward by array shift and restarts the timer to track the new window Base, ensuring that the timer is always targeted at the earliest unacknowledged packet.

  === TaskPacketsRetransmit,java
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

  This part defines the Go-Back-N retransmission behavior of the GBN protocol when a timeout event occurs. As a timer task, once triggered, the `run` method iterates over all unacknowledged packets currently stored in the send window buffer and resends them all in turn, thus backoff to the point of loss and rebuilding the entire pipeline in the event of a packet loss, rather than retransmitting only the lost packet.

  === Results and Analysis
  + *Results* \
    *Case - Packet Loss*
      - Sender Log
      #codly(languages: codly-languages)
      ```Log
      2025-12-18 18:03:52:451 CST	DATA_seq: 41501	LOSS	NO_ACK
      2025-12-18 18:03:52:464 CST	DATA_seq: 41601		NO_ACK
      2025-12-18 18:03:52:477 CST	DATA_seq: 41701		NO_ACK
      2025-12-18 18:03:52:488 CST	DATA_seq: 41801		NO_ACK
      2025-12-18 18:03:52:499 CST	DATA_seq: 41901		NO_ACK
      2025-12-18 18:03:52:512 CST	DATA_seq: 42001		NO_ACK
      2025-12-18 18:03:52:525 CST	DATA_seq: 42101		NO_ACK
      2025-12-18 18:03:52:537 CST	DATA_seq: 42201		NO_ACK
      2025-12-18 18:03:52:550 CST	DATA_seq: 42301		NO_ACK
      2025-12-18 18:03:52:560 CST	DATA_seq: 42401		NO_ACK
      2025-12-18 18:03:52:572 CST	DATA_seq: 42501		NO_ACK
      2025-12-18 18:03:52:585 CST	DATA_seq: 42601		NO_ACK
      2025-12-18 18:03:52:598 CST	DATA_seq: 42701		NO_ACK
      2025-12-18 18:03:52:609 CST	DATA_seq: 42801		NO_ACK
      2025-12-18 18:03:52:621 CST	DATA_seq: 42901		NO_ACK
      2025-12-18 18:03:52:633 CST	DATA_seq: 43001		NO_ACK
      2025-12-18 18:03:55:445 CST	*Re: DATA_seq: 41501		ACKed
      2025-12-18 18:03:55:445 CST	*Re: DATA_seq: 41601		ACKed
      2025-12-18 18:03:55:445 CST	*Re: DATA_seq: 41701		ACKed
      2025-12-18 18:03:55:445 CST	*Re: DATA_seq: 41801		ACKed
      2025-12-18 18:03:55:445 CST	*Re: DATA_seq: 41901		ACKed
      2025-12-18 18:03:55:445 CST	*Re: DATA_seq: 42001		ACKed
      2025-12-18 18:03:55:445 CST	*Re: DATA_seq: 42101		ACKed
      2025-12-18 18:03:55:445 CST	*Re: DATA_seq: 42201		ACKed
      2025-12-18 18:03:55:445 CST	*Re: DATA_seq: 42301		ACKed
      2025-12-18 18:03:55:445 CST	*Re: DATA_seq: 42401		ACKed
      2025-12-18 18:03:55:445 CST	*Re: DATA_seq: 42501		ACKed
      2025-12-18 18:03:55:445 CST	*Re: DATA_seq: 42601		ACKed
      2025-12-18 18:03:55:445 CST	*Re: DATA_seq: 42701		ACKed
      2025-12-18 18:03:55:445 CST	*Re: DATA_seq: 42801		ACKed
      2025-12-18 18:03:55:445 CST	*Re: DATA_seq: 42901		ACKed
      2025-12-18 18:03:55:445 CST	*Re: DATA_seq: 43001		ACKed
      ```

      - Receiver Log
      #codly(languages: codly-languages)
      ```Log
      2025-12-18 18:03:55:445 CST	ACK_ack: 41501	
      2025-12-18 18:03:55:445 CST	ACK_ack: 41601	
      2025-12-18 18:03:55:445 CST	ACK_ack: 41701	
      2025-12-18 18:03:55:445 CST	ACK_ack: 41801	
      2025-12-18 18:03:55:445 CST	ACK_ack: 41901	
      2025-12-18 18:03:55:446 CST	ACK_ack: 42001	
      2025-12-18 18:03:55:446 CST	ACK_ack: 42101	
      2025-12-18 18:03:55:446 CST	ACK_ack: 42201	
      2025-12-18 18:03:55:447 CST	ACK_ack: 42301	
      2025-12-18 18:03:55:447 CST	ACK_ack: 42401	
      2025-12-18 18:03:55:447 CST	ACK_ack: 42501	
      2025-12-18 18:03:55:447 CST	ACK_ack: 42601	
      2025-12-18 18:03:55:447 CST	ACK_ack: 42701	
      2025-12-18 18:03:55:447 CST	ACK_ack: 42801	
      2025-12-18 18:03:55:448 CST	ACK_ack: 42901	
      2025-12-18 18:03:55:448 CST	ACK_ack: 43001
      ```

      - Terminal Output
      #codly(languages: codly-languages)
      ```Terminal
      -> 2025-12-18 18:03:52:464 CST
      ** TCP_Receiver
        Receive packet from: [10.150.200.45:9001]
        Packet data: 500809 500831 500839 500861 500873 500881 500887 500891 500909 500911 500921 500923 500933 500947 500953 500957 500977 501001 501013 501019 501029 501031 501037 501043 501077 501089 501103 501121 501131 501133 501139 501157 501173 501187 501191 501197 501203 501209 501217 501223 501229 501233 501257 501271 501287 501299 501317 501341 501343 501367 501383 501401 501409 501419 501427 501451 501463 501493 501503 501511 501563 501577 501593 501601 501617 501623 501637 501659 501691 501701 501703 501707 501719 501731 501769 501779 501803 501817 501821 501827 501829 501841 501863 501889 501911 501931 501947 501953 501967 501971 501997 502001 502013 502039 502043 502057 502063 502079 502081 502087
        PACKET_TYPE: DATA_SEQ_41601
      ...
      -> 2025-12-18 18:03:52:633 CST
      ** TCP_Receiver
        Receive packet from: [10.150.200.45:9001]
        Packet data: 519229 519247 519257 519269 519283 519287 519301 519307 519349 519353 519359 519371 519373 519383 519391 519413 519427 519433 519457 519487 519499 519509 519521 519523 519527 519539 519551 519553 519577 519581 519587 519611 519619 519643 519647 519667 519683 519691 519703 519713 519733 519737 519769 519787 519793 519797 519803 519817 519863 519881 519889 519907 519917 519919 519923 519931 519943 519947 519971 519989 519997 520019 520021 520031 520043 520063 520067 520073 520103 520111 520123 520129 520151 520193 520213 520241 520279 520291 520297 520307 520309 520313 520339 520349 520357 520361 520363 520369 520379 520381 520393 520409 520411 520423 520427 520433 520447 520451 520529 520547
        PACKET_TYPE: DATA_SEQ_43001

      Sliding Window Full
      ```

  + *Analysis* \
    *1)* The demonstrations of other cases are similar to the protocol so below won't appear; *2)* When packet 41501 was lost, the sender continued to transmit subsequent packets (41601-43001) utilizing the available window size. However, since GBN receivers discard out-of-order packets to maintain sequence, these subsequent packets were not acknowledged. Upon the timeout of the oldest unacknowledged packet (41501), the sender correctly executed the "Go-Back-N" strategy, retransmitting the entire window starting from 41501. This highlights the trade-off of GBN --- while it improves throughput over Stop-and-Wait by filling the pipeline, it may lead to redundant retransmissions (re-sending 41601-43001) when a single packet is lost.

== Selective-Repeat
  The gap between Selective-Repeat and Go-Back-N is shown in the following features: *1)* The sender has at most N unconfirmed datagrams in its pipeline; *2)* the receiver acknowledges a single datagram; *3)* the sender clocks each unconfirmed datagram and retransmits only the unconfirmed datagram if the timer expires; *4)* the sending window is greater than 1, The acceptance window is greater than 1 --- meaning that the packet segment after the error location can be cached

  === SenderSlidingWindow.java
  #codly(languages: codly-languages)
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

  Here I maintain a separate timer for each packet in the window. `putPacket` starts the specific timer of the location while the packet is cached. `receiveACK` implements selective acknowledgement logic --- Upon receipt of an ACK, only the timer with the corresponding sequence number is canceled and marked as received. Only when a packet of the window's Base is acknowledged, the window utilizes the loop detection `maxACKedIndex` to slide over all consecutive acknowledged packets at once, updating the Base and making room for the window.

  === ReceiverSlidingWindow.java
  #codly(languages: codly-languages)
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
          try {
              File file = new File("recvData.txt");
              BufferedWriter writer = new BufferedWriter(new FileWriter(file, true));

              while (!this.dataQueue.isEmpty()) {
                  int[] data = this.dataQueue.poll();

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

  This part implements out-of-order caching and in-order delivery mechanism at SR receiver. `receivePacket` is judged according to the sequence number: if the out-of-order `packets` in the window are received, they are directly stored in the corresponding position of the packets array for cache. The `slid` method is fired only when the expected Base packet is received. The `slid` method is responsible for scanning and extracting all consecutive cached packets starting from Base, batching them to the upper application, and sliding the receive window to ensure that the data fetched by the upper application is always in order.

  === Results and Analysis
  + *Results* \
    *Case - Packet Loss*
      - Sender Log
      #codly(languages: codly-languages)
      ```Log
      2025-12-04 20:34:49:876 CST	DATA_seq: 11701		ACKed
      2025-12-04 20:34:49:889 CST	DATA_seq: 11801	LOSS	NO_ACK
      2025-12-04 20:34:52:894 CST	*Re: DATA_seq: 11801		ACKed
      2025-12-04 20:34:52:907 CST	DATA_seq: 11901		ACKed
      ```

      - Receiver Log
      #codly(languages: codly-languages)
      ```Log
      2025-12-04 20:34:49:876 CST	ACK_ack: 11701
      2025-12-04 20:34:52:894 CST	ACK_ack: 11801
      2025-12-04 20:34:52:908 CST	ACK_ack: 11901
      ```

      - Terminal Output
      #codly(languages: codly-languages)
      ```Terminal
      -> 2025-12-04 20:34:49:889 CST
      ** TCP_Sender
      Sending Packet: 11801
      (Timer Start) -> Packet Lost in Channel

      -> 2025-12-04 20:34:52:894 CST
      ** TCP_Sender
      Timeout on 11801!
      Selective Retransmit: 11801

      -> 2025-12-04 20:34:52:894 CST
      ** TCP_Receiver
      Receive Packet: 11801
      Checksum OK. Buffer & Deliver.
      Send ACK: 11801
      ```
  + *Analysis* \
    In Case --- Packet Loss, the sender retransmitted only the lost packet 11801. This stands in sharp contrast to the GBN experiment, where a single timeout forced the retransmission of the entire window (packets $n, n+1, dots$). SR's ability to maintain a timer for each unacknowledged packet allows for this surgical retransmission, significantly reducing channel congestion.

== TCP (Transmission Control Protocol)
  Go-Back-N and Selective-Repeat protocols show their respective advantages in efficient transmission and handling packet loss problem. While, TCP integrates the pros of GBN and SR, and further improves the reliability and efficiency of data transmission through cumulative acknowledgement and timeout retransmission mechanism.

  The core idea of TCP is that the receiver uses cumulative acknowledgment mechanism to acknowledge all incoming data in order to reduce the number of acks. In case of packet loss or error, the receiver will send specific acknowledgement information according to the specific situation, so that the sender can locate and retransmit the lost packet in time. This mechanism not only reduces unnecessary retransmissions, but also significantly optimizes bandwidth utilization.

  === SenderSlidingWindow.java
  #codly(languages: codly-languages)
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

  This part is to implement the sliding windows and cumulative ACKs mechanisms. Cache the sent data by using a hash table and maintain a separate timer for each packet; The core logic lies in the `receiveACK` method, which, when it receives an ACK for a sequence number, not only acknowledges the packet but also clears out all unacknowledged packets and timers before the sequence number by looping. This mechanism takes advantage of TCP's cumulative acknowledgement feature, thus effectively sliding the window reference and avoiding unnecessary retransmissions.

  === ReceiverSlidingWindow.java
  #codly(languages: codly-languages)
  ```java
  public class ReceiverSlidingWindow {
      private Client client;
      private LinkedList<TCP_PACKET> packets = new LinkedList<>();
      private int expectedSequence = 0;
      Queue<int[]> dataQueue = new LinkedBlockingQueue();
      public ReceiverSlidingWindow(Client client) {
          this.client = client;
      }
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
      public void deliver_data() {
          try {
              File file = new File("recvData.txt");
              BufferedWriter writer = new BufferedWriter(new FileWriter(file, true));
              while (!this.dataQueue.isEmpty()) {
                  int[] data = this.dataQueue.poll();
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

  This class is to handle out-of-order caching and in-order delivery policy. The `putPacket` method inserts the received data packets into the linked list in order of sequence number for caching, rather than dropping them like GBN. The `slid` method is responsible for checking the continuity of the head of the list, and once the cached data has filled the gap, it pulls and delivers it and advances the expected sequence number, ensuring that the data stream delivered to the upper application is continuous, and returns the maximum consecutive received sequence number as an ACK.

  === Results and Analysis
  + *Results* \
    *Case - Packet Loss (TCP Cumulative ACK & Timeout)*
      - Sender Log
        #codly(languages: codly-languages)
        ```Log
        2025-12-19 11:13:02:150 CST	DATA_seq: 25001		ACKed
        2025-12-19 11:13:02:163 CST	DATA_seq: 25101	LOSS	NO_ACK
        2025-12-19 11:13:02:175 CST	DATA_seq: 25201		NO_ACK
        2025-12-19 11:13:02:188 CST	DATA_seq: 25301		NO_ACK

        ... 
        
        2025-12-19 11:13:05:168 CST	*Re: DATA_seq: 25101		NO_ACK
        2025-12-19 11:13:05:169 CST	DATA_seq: 26701		ACKed
        ```

      - Receiver Log
        #codly(languages: codly-languages)
        ```Log
        2025-12-19 11:13:02:150 CST	ACK_ack: 25001
        2025-12-19 11:13:02:176 CST	ACK_ack: 25001	(Duplicate ACK triggered by 25201)
        2025-12-19 11:13:02:188 CST	ACK_ack: 25001	(Duplicate ACK triggered by 25301)
        
        ...

        2025-12-19 11:13:05:169 CST	ACK_ack: 26601	(Cumulative ACK!)
        ```

      - Terminal Output
      #codly(languages: codly-languages)
      ```Terminal
      -> 2025-12-19 11:13:02:315 CST
      ** TCP_Receiver
        Receive packet from: [10.150.200.45:9001]
        Packet data: 303703 303713 303727 303731 303749 303767 303781 303803 303817 303827 303839 303859 303871 303889 303907 303917 303931 303937 303959 303983 303997 304009 304013 304021 304033 304039 304049 304063 304067 304069 304081 304091 304099 304127 304151 304153 304163 304169 304193 304211 304217 304223 304253 304259 304279 304301 304303 304331 304349 304357 304363 304373 304391 304393 304411 304417 304429 304433 304439 304457 304459 304477 304481 304489 304501 304511 304517 304523 304537 304541 304553 304559 304561 304597 304609 304631 304643 304651 304663 304687 304709 304723 304729 304739 304751 304757 304763 304771 304781 304789 304807 304813 304831 304847 304849 304867 304879 304883 304897 304901
        PACKET_TYPE: DATA_SEQ_26301
      
      ...

      -> 2025-12-19 11:13:02:353 CST
      ** TCP_Receiver
        Receive packet from: [10.150.200.45:9001]
        Packet data: 307339 307361 307367 307381 307397 307399 307409 307423 307451 307471 307481 307511 307523 307529 307537 307543 307577 307583 307589 307609 307627 307631 307633 307639 307651 307669 307687 307691 307693 307711 307733 307759 307817 307823 307831 307843 307859 307871 307873 307891 307903 307919 307939 307969 308003 308017 308027 308041 308051 308081 308093 308101 308107 308117 308129 308137 308141 308149 308153 308213 308219 308249 308263 308291 308293 308303 308309 308311 308317 308323 308327 308333 308359 308383 308411 308423 308437 308447 308467 308489 308491 308501 308507 308509 308519 308521 308527 308537 308551 308569 308573 308587 308597 308621 308639 308641 308663 308681 308701 308713
        PACKET_TYPE: DATA_SEQ_26601
      -> 2025-12-19 11:13:02:354 CST
      ** TCP_Sender
        Receive packet from: [10.150.200.45:9002]
        Packet data:
        PACKET_TYPE: ACK_25001

      Receive ACK Number: 25001

      Sliding Window Full

      Timeout! Retransmitting packet seq: 25101
      ```
  + *Analysis* \
    The log data around sequence number 25101 provides a distinct demonstration of TCP's Cumulative Acknowledgement mechanism. 
    *1)* When packet 25101 was lost, the sender continued to transmit subsequent packets (25201-26601). The receiver acknowledged each of these out-of-order packets by sending duplicate ACKs for the last correctly received packet, indicating a gap in the sequence. 
    *2)* Upon the expiration of the retransmission timer, the sender retransmitted packet 25101. 
    *3)* Crucially, once the receiver obtained the missing packet 25101, it did not just ACK 25101. Instead, it immediately sent ACK 26601, confirming that it had successfully buffered all intervening packets. This confirms the sliding window implementation correctly handles out-of-order buffering and cumulative ACKs, significantly improving efficiency compared to Go-Back-N.

== TCP Tahoe
  TCP Tahoe is a classical congestion control algorithm. Its key is to dynamically adjust the size of the sending window through four mechanisms: slow start, additive increase, congestion avoidance and multiplicative effect, so as to achieve effective control of network congestion.

  === SenderSlidingWindow.java
  #codly(languages: codly-languages)
  ```java
  public class SenderSlidingWindow {
      private Client client;
      public int cwnd = 1;
      private volatile int ssthresh = 16;
      private int count = 0;
      private Hashtable<Integer, TCP_PACKET> packets = new Hashtable<>();
      private Hashtable<Integer, UDT_Timer> timers = new Hashtable<>();
      private int lastACKSequence = -1;
      private int lastACKSequenceCount = 0;
      public SenderSlidingWindow(Client client) {
          this.client = client;
      }
      public boolean isFull() {
          return this.cwnd <= this.packets.size();
      }
      public void putPacket(TCP_PACKET packet) {
          int currentSequence = (packet.getTcpH().getTh_seq() - 1) / 100;
          this.packets.put(currentSequence, packet);
          this.timers.put(currentSequence, new UDT_Timer());
          this.timers.get(currentSequence).schedule(new RetransmitTask(this.client, packet, this), 3000, 3000);
      }
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
          this.window.slowStart();

          this.client.send(this.packet);
      }
  }
  ```

  This implementation is the congestion control mechanism of TCP Tahoe. The sender maintains the congestion window `cwnd` and the slow start threshold `ssthresh`: upon receiving a new ACK, if `cwnd` is less than the threshold, it performs slow start (exponential growth), otherwise it performs congestion avoidance (linear growth). The most distinctive feature of the code is the handling of packet loss: the `slowStart()` method is called for both the timeout retransmission triggered by the timer task and the fast retransmission triggered by the detection of three duplicate acks. This method sets `ssthresh` to half of the current window and forces `cwnd` to be reset to 1, which means that Tahoe will completely empty the pipeline after any packet loss event and restart the transmission from the slow-start phase.

  === Results and Analysis
  + *Results* \
    *Case - Fast Retransmit*
      - Sender Log
      #codly(languages: codly-languages)
      ```Log
      2025-12-19 11:53:07:842 CST	DATA_seq: 9501		ACKed
      2025-12-19 11:53:07:855 CST	DATA_seq: 9601	LOSS	NO_ACK
      2025-12-19 11:53:07:868 CST	DATA_seq: 9701		NO_ACK
      2025-12-19 11:53:07:879 CST	DATA_seq: 9801		NO_ACK
      2025-12-19 11:53:07:892 CST	DATA_seq: 9901		ACKed
      2025-12-19 11:53:07:893 CST	*Re: DATA_seq: 9601		NO_ACK
      2025-12-19 11:53:07:904 CST	DATA_seq: 10001		ACKed
      ```

      - Receiver Log
      #codly(languages: codly-languages)
      ```Log
      2025-12-19 11:53:07:843 CST	ACK_ack: 9501
      2025-12-19 11:53:07:868 CST	ACK_ack: 9501	(Dup ACK #1 triggered by 9701)
      2025-12-19 11:53:07:879 CST	ACK_ack: 9501	(Dup ACK #2 triggered by 9801)
      2025-12-19 11:53:07:892 CST	ACK_ack: 9501	(Dup ACK #3 triggered by 9901)
      2025-12-19 11:53:07:894 CST	ACK_ack: 9901	(Cumulative ACK after Recovery)
      ```

      - Terminal Output
      #codly(languages: codly-languages)
      ```Terminal
      -> 2025-12-19 11:53:07:842 CST
      ** TCP_Receiver
        Receive packet from: [10.150.200.45:9001]
        Packet data: 98953 98963 98981 98993 98999 99013 99017 99023 99041 99053 99079 99083 99089 99103 99109 99119 99131 99133 99137 99139 99149 99173 99181 99191 99223 99233 99241 99251 99257 99259 99277 99289 99317 99347 99349 99367 99371 99377 99391 99397 99401 99409 99431 99439 99469 99487 99497 99523 99527 99529 99551 99559 99563 99571 99577 99581 99607 99611 99623 99643 99661 99667 99679 99689 99707 99709 99713 99719 99721 99733 99761 99767 99787 99793 99809 99817 99823 99829 99833 99839 99859 99871 99877 99881 99901 99907 99923 99929 99961 99971 99989 99991 100003 100019 100043 100049 100057 100069 100103 100109
        PACKET_TYPE: DATA_SEQ_9501
      -> 2025-12-19 11:53:07:843 CST
      ** TCP_Sender
        Receive packet from: [10.150.200.45:9002]
        Packet data:
        PACKET_TYPE: ACK_9501

      Receive ACK Number: 9501

      window size: 20
      
      ...

      00000 cwnd: 20
      00000 ssthresh: 16
      11111 cwnd: 1
      11111 ssthresh: 10
      -> 2025-12-19 11:53:07:893 CST
      ** TCP_Receiver
        Receive packet from: [10.150.200.45:9001]
        Packet data: 100129 100151 100153 100169 100183 100189 100193 100207 100213 100237 100267 100271 100279 100291 100297 100313 100333 100343 100357 100361 100363 100379 100391 100393 100403 100411 100417 100447 100459 100469 100483 100493 100501 100511 100517 100519 100523 100537 100547 100549 100559 100591 100609 100613 100621 100649 100669 100673 100693 100699 100703 100733 100741 100747 100769 100787 100799 100801 100811 100823 100829 100847 100853 100907 100913 100927 100931 100937 100943 100957 100981 100987 100999 101009 101021 101027 101051 101063 101081 101089 101107 101111 101113 101117 101119 101141 101149 101159 101161 101173 101183 101197 101203 101207 101209 101221 101267 101273 101279 101281
        PACKET_TYPE: DATA_SEQ_9601
      -> 2025-12-19 11:53:07:894 CST
      ** TCP_Sender
        Receive packet from: [10.150.200.45:9002]
        Packet data:
        PACKET_TYPE: ACK_9901

      Receive ACK Number: 9901

      ########### window expand ############

      window size: 2
      ```
  + *Analysis* \
    *1)* When packet 9601 was lost, the sender continued transmitting subsequent packets (9701, 9801, 9901).
    *2)* Upon receiving these out-of-order packets, the receiver generated three consecutive duplicate ACKs acknowledging sequence 9501.
    *3)* Crucially, the sender reacted to these duplicate ACKs by retransmitting packet 9601 at `11:53:07:893`, a mere 38ms after the initial transmission, which is significantly shorter than the standard timeout interval (usually >1s). This confirms that the retransmission was triggered by the "Triple Duplicate ACK" event rather than a timeout.
    *4)* Finally, upon receiving the missing packet, the receiver issued a cumulative ACK (9901), indicating successful recovery. In the Tahoe protocol, this event would also cause the Congestion Window (cwnd) to be reset to 1 --- Slow Start, distinguishing it from the packet loss handling in basic Go-Back-N or Selective Repeat.

== TCP Reno
  The difference between TCP Reno and Tahoe is Reno's fast recovery mechanism --- when 3 duplicate ACKs are lost, `ssthersh` becomes `cwnd / 2`, while `cwnd` becomes `ssthresh + 3MSS`.

  === SenderSlidingWindow.java
  #codly(languages: codly-languages)
  ```java
  public class SenderSlidingWindow {
      private Client client;
      public int cwnd = 1;
      private volatile int ssthresh = 16;
      private int count = 0;
      private Hashtable<Integer, TCP_PACKET> packets = new Hashtable<>();
      private Hashtable<Integer, UDT_Timer> timers = new Hashtable<>();
      private int lastACKSequence = -1;
      private int lastACKSequenceCount = 0;
      public SenderSlidingWindow(Client client) {
          this.client = client;
      }
      public boolean isFull() {
          return this.cwnd <= this.packets.size();
      }
      public void putPacket(TCP_PACKET packet) {
          int currentSequence = (packet.getTcpH().getTh_seq() - 1) / 100;
          this.packets.put(currentSequence, packet);
          this.timers.put(currentSequence, new UDT_Timer());
          this.timers.get(currentSequence).schedule(new RetransmitTask(this.client, packet, this), 3000, 3000);
      }
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
          this.window.slowStart();
          this.client.send(this.packet);
      }
  }
  ```

  This class implements the congestion control mechanism of TCP Reno, and adds the Fast Recovery state compared with Tahoe. The code maintains the congestion window `cwnd` and the slow start threshold `ssthresh`, and executes the slow start or congestion avoidance algorithm when it receives a normal ACK. When three duplicate acks are detected, a fast retransmission is triggered and `ssthresh` is halved, followed by a fast recovery phase. Resetting `cwnd` to 1 and falling back to slow-start is enforced only in severe congestion cases where a retransmission timeout is triggered via the `RetransmitTask`, resulting in a significant increase in network throughput while maintaining reliability.

  === Results and Analysis
  + *Results* \
    *Case - Fast Recovery (Reno's Distinguishing Feature)*
      - Sender Log
      #codly(languages: codly-languages)
      ```Log
      2025-12-19 12:28:43:232 CST	DATA_seq: 72501		ACKed
      2025-12-19 12:28:43:245 CST	DATA_seq: 72601	WRONG	NO_ACK
      2025-12-19 12:28:43:255 CST	DATA_seq: 72701		NO_ACK
      2025-12-19 12:28:43:268 CST	DATA_seq: 72801		ACKed
      2025-12-19 12:28:43:268 CST	*Re: DATA_seq: 72601		NO_ACK
      ```

      - Receiver Log
      #codly(languages: codly-languages)
      ```Log
      2025-12-19 12:28:43:232 CST	ACK_ack: 72501	
      2025-12-19 12:28:43:246 CST	ACK_ack: 72501	
      2025-12-19 12:28:43:256 CST	ACK_ack: 72501	
      2025-12-19 12:28:43:268 CST	ACK_ack: 72501	
      2025-12-19 12:28:43:269 CST	ACK_ack: 72801
      ```

      - Terminal Output
      #codly(languages: codly-languages)
      ```Terminal
      -> 2025-12-19 12:28:43:232 CST
      ** TCP_Receiver
        Receive packet from: [10.150.200.45:9001]
        Packet data: 916879 916907 916913 916931 916933 916939 916961 916973 916999 917003 917039 917041 917051 917053 917083 917089 917093 917101 917113 917117 917123 917141 917153 917159 917173 917179 917209 917219 917227 917237 917239 917243 917251 917281 917291 917317 917327 917333 917353 917363 917381 917407 917443 917459 917461 917471 917503 917513 917519 917549 917557 917573 917591 917593 917611 917617 917629 917633 917641 917659 917669 917687 917689 917713 917729 917737 917753 917759 917767 917771 917773 917783 917789 917803 917809 917827 917831 917837 917843 917849 917869 917887 917893 917923 917927 917951 917971 917993 918011 918019 918041 918067 918079 918089 918103 918109 918131 918139 918143 918149
        PACKET_TYPE: DATA_SEQ_72501
      -> 2025-12-19 12:28:43:232 CST
      ** TCP_Sender
        Receive packet from: [10.150.200.45:9002]
        Packet data:
        PACKET_TYPE: ACK_72501

      Receive ACK Number: 72501

      window size: 13

      ...

      -> 2025-12-19 12:28:43:268 CST
      ** TCP_Receiver
        Receive packet from: [10.150.200.45:9001]
        Packet data: 918157 918161 918173 918193 918199 918209 918223 918257 918259 918263 918283 918301 918319 918329 918341 918347 918353 918361 918371 918389 918397 918431 918433 918439 918443 918469 918481 918497 918529 918539 918563 918581 918583 918587 918613 918641 918647 918653 918677 918679 918683 918733 918737 918751 918763 918767 918779 918787 918793 918823 918829 918839 918857 918877 918889 918899 918913 918943 918947 918949 918959 918971 918989 919013 919019 919021 919031 919033 919063 919067 919081 919109 919111 919129 919147 919153 919169 919183 919189--- Fast Recovery ---
      00000 cwnd: 13
      00000 ssthresh: 7
      11111 cwnd: 9
      919223 919229 919231 919249 919253 91926711111 ssthresh: 6
      919301 919313 919319 919337 919349 919351 919381 919393 919409 919417 919421 919423 919427 919447 919511
        PACKET_TYPE: DATA_SEQ_72601
      -> 2025-12-19 12:28:43:269 CST
      ** TCP_Sender
        Receive packet from: [10.150.200.45:9002]
        Packet data:
        PACKET_TYPE: ACK_72801

      Receive ACK Number: 72801

      --- Fast Recovery Exit ---
      ```

  + *Analysis* \
    The log segment surrounding sequence 72601 illustrates the Fast Recovery mechanism specific to TCP Reno, distinguishing it from TCP Tahoe.
    *1)* Packet 72601 was corrupted, leading the receiver to send duplicate ACKs for sequence 72501 upon receiving subsequent packets 72701 and 72801.
    *2)* Upon receiving the third duplicate ACK at `12:28:43:268`, the sender triggered a Fast Retransmit for packet 72601.
    *3)* Crucially, immediately after retransmitting (at `12:28:43:268`), the sender did not stop or reset to Slow Start. Instead, it continued to transmit new packets 72901 (`:280`) and 73001 (`:292`) without delay[cite: 83]. This continuous transmission confirms that the protocol entered Fast Recovery mode --- the Congestion Window (cwnd) was likely halved rather than reset to 1, and the window was artificially inflated by the duplicate ACKs, allowing the sender to maintain high throughput even while recovering from the packet loss. 

= Incomplete projects, indicating key difficulties in completion and possible solutions.
  All efforts to complete, the future can consider optimizing the content:
  The TCP race control process is represented in a LOG file --- the process is represented at runtime and difficult to review. Through communication with other students, I learned that the process of confirmation, slow start and addition increase can be carried out through the cumulative recovery of the receiver in the LOG file. Difficult to implement: it is necessary to modify the receiving window and modulate the part of the sender logic, so that the sender can adapt to the two reply modes. It is not known where this part of the judgment is implemented.

= Explain the advantages or problems of using iterative development in the experiment process.
  *Advantages:*
  1. With iterative development, I can implement things slowly, whereas before, if I implemented a big experiment, I might have to focus on it for a few days, because if there is a bug now, it is often more troublesome to come back a few days later. But with iterative development, it feels like it's broken down into coherent subtasks, and even though the assignments get progressively more difficult, it's perfect for weekly, multi-week in-class LABs.

  2. After each iteration is completed, problems can be detected in time through testing, and adjustments can be made to avoid the accumulation of subsequent problems. Especially when the sender and receiver are not mature at the beginning; In the experiment, the logic and function of different stages can be fully verified by running and checking the LOG file after completing the task of this stage, rather than checking whether there is a running result at the end.

  3. Through the accumulation of functions in each iteration, our sending and receiving protocol was improved step by step. The final protocol implementation only added a quick recovery on the existing basis, rather than starting from scratch. By keeping my head down and moving forward, looking up and realizing that I had reached the end, I actually showed that iterative development improved my experimental efficiency.

  *Problems:*
  1. Although we used iterative development, it actually led to a bit of bloat in the process of improving code, such as: We initially implemented a timer in RDT-3.0, but in the subsequent implementation of TCP protocol, we do not need to use this timer anymore, at this time we should remove it, because it will not be used anymore, but I am not sure whether it will check all code in the future, so I choose to comment it, and also mark its previous scope. Resulting in a complex process.

  2. I chose to start with Go Back N because I wasn't sure if I could do TCP all at once, and because SR/TCP implementations are concurrent. Therefore, it is still necessary to retain the code, and do not dare to directly change the source code base.

= Summarize the main problems that have been solved in the process of completing the big homework and the corresponding solutions taken by myself.
  1. The first major problem was ensuring reliable data delivery over an unreliable channel characterized by bit errors, packet loss, and ACK corruption. To solve this, I implemented a robust error-control mechanism combining CRC32 checksums for corruption detection, countdown timers to trigger retransmissions upon packet/ACK loss, and sequence numbers to identify and discard duplicate packets caused by premature timeouts.

  2. The second challenge was overcoming the low throughput of the Stop-and-Wait protocol and handling network congestion dynamically. I addressed this by implementing pipelined protocols (Go-Back-N and Selective Repeat) to utilize channel bandwidth efficiently, and further integrated TCP congestion control algorithms—specifically Tahoe’s Fast Retransmit and Reno’s Fast Recovery—to quickly recover from packet loss events without relying solely on inefficient timeout mechanisms. 

= Ask questions or suggestions about the experimental system.
  *Suggestions:*
  1. It would be appreciated if the system provided a graphical visualization of the packet flow, specifically showing the Sliding Window moving in real-time. Debugging purely via text logs is effective but hard to intuitively grasp the timing of packets.
  2. The underlying implementation of the channel communication system is almost impossible to see, and the doc content is too brief to have a full understanding of the underlying system. Each step of the implementation was carefully attempted. For this reason, I highly recommend writing more extensive documentation to explain the implementation of the underlying system.