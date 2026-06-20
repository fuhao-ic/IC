init

note：
    github无法正常提交fix方法：
        场景：开启vpu也无法提交：
            执行下面命令：设置 Git 全局代理
                git config --global http.proxy http://127.0.0.1:7890
                git config --global https.proxy http://127.0.0.1:7890
            取消代理命令：
                git config --global --unset http.proxy
                git config --global --unset https.proxy

这个repo开始于2026-06-19，主要目的是用于coding练习基础的数字电路设计，比如ram、rom、fifo（同步/异步）、各类小ip（uart， spi，i2c等等）；


开源画示意图软件： [https://app.diagrams.net/](https://)



这里用于记录做过哪些基础的数字电路设计：

* rom
