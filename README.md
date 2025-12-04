<div align="center">
    <h1> Computer-Network-Lab </h1>
    <h3> Stanley ZHAO </h3>
</div>

### Objective
实现从 RDT-1.0 到 TCP Reno 的

### RDT / TCP Version
- RDT 1.0: 在可靠信道上进行可靠的数据传输
- RDT 2.0: 信道上可能出现位错
- RDT 2.1: 管理出错的 ACK/NAK
- RDT 2.2: 无 NAK 的协议
- RDT 3.0: 通道上可能出错和丢失数据
- RDT 4.0: 流水线协议 Go-Back-N, Selective-Response
= RDT 5.0: 拥塞控制 Tahoe, Reno

### eFlag Instruction
- eFlag = 0: 信道无差错
- eFlag = 1: 只出错
- eFlag = 2: 只丢包
- eFlag = 3: 只延迟
- eFlag = 4: 出错 / 丢包
- eFlag = 5: 出错 / 延迟
- eFlag = 6: 丢包 / 延迟
- eFlag = 7: 出错 / 丢包 / 延迟

|    *Version*     | Sender | Receiver |
|:----------------:|:------:|:--------:|
|     RDT 1.0      |   0    |    0     |
|     RDT 2.0      |   1    |    0     |
|     RDT 2.1      |   1    |    1     |
|     RDT 2.2      |   1    |    1     |
|     RDT 3.0      |   4    |    4     |
|    Go-Back-N     |   7    |    7     |
| Selective-Repeat |   7    |    7     |
|       TCP        |   \    |    \     |
|    TCP Tahoe     |   \    |    \     |
|     TCP Reno     |   \    |    \     |

## Install
本项目使用 IntelliJ IDEA 编写，IDEA 可通过 Computer-Network-Lab.iml 导入项目。

> Java version: 
Oracle OpenJDK 1.8.0_471 - aarch64

## Usage
将 jars 文件夹中对应平台的 jar 包放到 lib 文件夹中:
- Windows 使用 TCP_TestSys_4_Windows.jar
- MacOS 和 Linux 使用 TCP_TestSys_4_Linux_and_MacOS.jar

运行 TestRun.java，等待传输完毕，最后需手动结束进程。

运行日志存放于 Log.txt，接收的数据存放于 recvData.txt。