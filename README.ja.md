# boot_breakout - OS不要なブロック崩し


ブートセクタで動く512バイトのブロック崩し（510バイト＋ブートシグネチャの2バイト）です。

[ブラウザ上のエミュレータでも動きます。](https://couyoh.github.io/boot_breakout/)

![Demo](demo/demo.gif)

## ビルド

NASMが必要です。

```shell
make
```


## 起動

QEMUが必要です。VirtualBoxなどでも、`make`によって生成される`build/main.bin`をVMのフロッピーイメージとすることで起動できます。

起動後は、<kbd>Left</kbd> キーまたは <kbd>Right</kbd> キーでパドルが動きます。

```shell
make qemu
```
