## Types
---
`U8` type
unsigned integer 8-bit

---
`BB` type
6 bytes
index range is bit index
```
|-BB--------------------------------------|
|-47:42---|-41:31-|-30:20-|-19:10-|-9:0---|
| padding | xmin  | xmax  | ymin  | ymax  |
```
---
## packet structure
bb: bounding box
index range is byte index
```
|-header-------------------------|-features------------------|
| frame count | number of bb <n> | bb0 | bb1 | ... | bb<n-1> |
|-------------|------------------|-----|-----|-----|---------|
| U8          | U8               | BB  | BB  | ... | BB      |
```
