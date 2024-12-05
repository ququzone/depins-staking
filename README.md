## Depins Staking

## Deployment

### Testnet

```
Depins deployed to: '0x5Af53c76C5CF675b95E64007f054F5EC7ac9D615'
DepinsStaking deployed to: '0x31AB580A7A0d5d2A0f12c1F0E7bdF795dfaEC82A'
```

```
cast send 0x9eb5E38CE77Ca5fBB0e91b4ba2fCDb2f857e0180 'newStakingType(uint64,uint64,uint64,uint64)' \
 0 5270400 0 1370 \
 --legacy --keystore 

cast send 0x9eb5E38CE77Ca5fBB0e91b4ba2fCDb2f857e0180 'newStakingType(uint64,uint64,uint64,uint64)' \
 1 86400 172800 410 \
 --legacy --keystore 
```
