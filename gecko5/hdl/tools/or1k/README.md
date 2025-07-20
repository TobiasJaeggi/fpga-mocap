# disclaimer
These tools are compiled for `amd64` architecture.
# about
Tools required to run custom code on the or1420 soft core.
ork1toolchain.zip contains the compiler, linker, etc.
convert_or32 is used to convert the toolchains output (.elf) to the format required by the or1420 softcore (.cmem).
# install
## ork1toolchain
1. extract ork1toolchain.zip to /opt/or1k_toolchain:
```
/opt/or1k_toolchain
├── bin
├── include
├── lib
├── libexec
├── or1k-elf
└── share
```
2. add bin folder to the system path
`export PATH="/opt/or1k_toolchain/bin:$PATH"`
(add to `~/.bashrc` or corresponding file of your shell)
## convert_or32
1. Copy convert_or32 to /opt/convert_o32/bin.
```
/opt/convert_or32/
└── bin
    └── convert_or32
```
2. add bin folder to the system path
`export PATH="/opt/convert_or32/bin:$PATH"`
(add to `~/.bashrc` or corresponding file of your shell)
