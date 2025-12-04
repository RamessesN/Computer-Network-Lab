/******************** RDT 2.0 ********************/
/************ Yuwei ZHAO (2025-12-03) ************/

package com.ouc.tcp.test;

import com.ouc.tcp.message.TCP_HEADER;
import com.ouc.tcp.message.TCP_PACKET;

import java.util.zip.CRC32;

public class CheckSum {
	public static short computeChkSum(TCP_PACKET tcpPack) { // Calculate the checksum of the TCP packet (Only verify the seq, ack and data fields in the TCP header)
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