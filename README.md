<div align="center">
    <h2> Ocean University of China </h2>
    <h1> Computer-Network-Lab </h1>
</div>

<img src="./doc/img/ouc.png" alt="ouc_alt" title="ouc_img">

---

## 一、实验简介
中国海洋大学 计算机(含中外) TCP 计算机网络大实验：实现从 RDT-1.0 到 TCP Reno 的全过程模拟。

---

## 二、项目结构
<pre>
<code>Computer-Network-Lab/
├── doc/         # api 参考和实验要求
│   └── ...
├── jars/        # 底层库 source (win/mac/linux)
│   └── ...
├── lib/         # 实际加载的 lib
│   └── ...
├── result/      # 实验结果 (RDT-1.0 to TCP-Reno)
│   ├── RDT-1.0/
│   │   ├── output/ 
│   │   │   ├── Log.txt       # 运行日志
│   │   │   └── RecvData.txt  # 接收数据
│   │   ├── CheckSum.java
│   │   ├── TCP_Receiver.java
│   │   └── TCP_Sender.java
│   ├── RDT-2.0/
│   │   └── ...
│   ├── result.iml    # IntelliJ IDEA 相关 env
│   └── ...
├── src/com/ouc/tcp/test/      # 在这运行代码
│   └── ...
├── Computer-Network-Lab.iml   # IntelliJ IDEA 相关 env
├── Config.ini    # TCP 实验 env
├── ENCDA.tcp     # TCP 实验 env
├── LICENSE       # 开源声明
└── README.md     # 项目介绍
</code>
</pre>

---

## 三、具体内容
### RDT / TCP 版本说明
| *Version*                    | Premise                 |
|------------------------------|-------------------------|
| RDT-1.0                      | 完全可信的信道                 |
| RDT 2.0                      | 可能出现 bit 错误             |
| RDT 2.1                      | 管理出错的 ACK / NAK         |
| RDT 2.2                      | 去除冗余的 NAK               |
| RDT 3.0                      | 通道上可能出错和丢失数据            |
| Go-Back-N / Selective-Repeat | 流水线协议                   |
| TCP                          | 引入超时机制                  |
| TCP Tahoe / Reno             | 拥塞控制                    |

### eFlag 说明
- eFlag = 0: 信道无差错
- eFlag = 1: 只出错
- eFlag = 2: 只丢包
- eFlag = 3: 只延迟
- eFlag = 4: 出错 / 丢包
- eFlag = 5: 出错 / 延迟
- eFlag = 6: 丢包 / 延迟
- eFlag = 7: 出错 / 丢包 / 延迟

### 版本号 - Sender / Receiver 端 eFlag 对照表
|    *Version*     | Sender | Receiver |
|:----------------:|:------:|:--------:|
|     RDT 1.0      |   0    |    0     |
|     RDT 2.0      |   1    |    0     |
|     RDT 2.1      |   1    |    1     |
|     RDT 2.2      |   1    |    1     |
|     RDT 3.0      |   4    |    4     |
|    Go-Back-N     |   7    |    7     |
| Selective-Repeat |   7    |    7     |
|       TCP        |   7    |    7     |
|    TCP Tahoe     |   7    |    7     |
|     TCP Reno     |   7    |    7     |

---

## 四、开发环境
- (本人) *Apple Silicon* - based mac with macOS26 (Windows 更没问题)
- IntelliJ IDEA (可直接通过 Computer-Network-Lab.iml 导入)
- Java ([Oracle OpenJDK 1.8.0_471 - aarch64](https://www.oracle.com/java/technologies/javase/javase8-archive-downloads.html))

---

## 五、使用说明
1. 将 jars 中对应 OS 的 Test 包放到 lib 文件夹中:
- Windows: `TCP_TestSys_4_Windows.jar`
- MacOS / Linux: `TCP_TestSys_4_Linux_and_MacOS.jar`

2. 运行 `TestRun.java` 测试能否跑通，等待进程结束 (*Notice*: 最后需手动结束进程)

3. 修改 `CheckSum.java` & `TCP_Receiver.java` & `TCP_Sender.java` 其中内容以实现完整实验
(*Notice*: GBN 及以后需要新建 `SenderSlidingWindow.java` & `ReceiverSlidingWindow.java` 增加滑动窗口功能)

4. 保存实验日志 (Log.txt) 和接收数据 (RecvData.txt) 并将完整代码存入对应 block


#### ⚠️ License: 该项目非开源. 详见 [LICENSE](./LICENSE).

---

<img src="./Doc/img/ouc2.png" alt="ouc2_alt" title="ouc2_img">