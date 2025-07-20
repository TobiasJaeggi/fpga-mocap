## general
Byte order is little-endian.
## packet structure
```
request
|-head----------------------------------|-data-----------------------------------|
| request id | cmd id | reserved | size |                                        |
|------------|--------|----------|------|----------------------------------------|
| U8         | U8     | U8       | U8   | cmd id based formatting for size bytes |

response
|-head----------------------------------|-data-----------------------------------|
| request id | cmd id | complete | size |                                        |
|------------|--------|----------|------|----------------------------------------|
| U8         | U8     | COMPLETE | U8   | cmd id based formatting for size bytes |
```

**`request id`**
A response to a request can be identified by having the same `request id`.
The `request id` `0x00` is reserved for a broadcast response which applies to all pending requests.

**`cmd id`**
Command ID.

**`reserved / complete`**
Specifies the completions status of the command.

**`size`**
The size of the `data` field in bytes.

**`data`**
Data with formatting based on the `cmd id` field.
## Types
---
`U8` type
unsigned integer 8-bit

---
`U16` type
unsigned integer 16-bit

---
`U32` type
unsigned integer 32-bit

---
`F32` type
floating point 32-bit

---
`MAC` type
MAC address: `octet0:octet1:octet2:octet3:octet4:octet5`
```
|-MAC-------------------------------------------------|
|-octet0-|-octet1-|-octet2-|-octet3-|-octet4-|-octet5-|
| U8     | U8     | U8     | U8     | U8     | U8     |
```
---
`IPV4` type
IPv4 address: `octet0.octet1.octet2.octet3`
```
|-IPV4------------------------------|
|-octet0-|-octet1-|-octet2-|-octet3-|
| U8     | U8     | U8     | U8     |
```
---
`MTX_<m>x<n>` type
m x n matrix with `float32` entries
m: row, n: col
```
┌                   ┐
│a11, a12, ... , a1n│
│a21, a22, ... , a2n│
 .    .          .
 .    .          .
 .    .          .
│am1, am2, ... , amn│
└                   ┘
```

```
|-MTX_<m>x<n>---------------------------------------------------------|
|-Row-1---------------|-Row-2---------------|...|-Row-m---------------| 
|-a11-|-a12-|...|-a1n-|-a21-|-a22-|...|-a2n-|...|-am1-|-am2-|...|-amn-|
| F32 | F32 |...| F32 | F32 | F32 |...| F32 |...| F32 | F32 |...| F32 |
```
## Enums
---
`COMPLETE` enum:
`0x00`: Completion failed
`0x01`: Completed successfully
```
|-COMPLETE-|
|-enum-----|
| U8       |
```
---
`PIPELINE_INPUT` enum:
`0x00`: Camera
`0x01`: Fake Static
`0x02`: Fake Moving
```
|-PIPELINE_INPUT-|
|-enum-----------|
| U8             |
```
---
`PIPELINE_OUTPUT` enum:
`0x00`: Unprocessed
`0x01`: Binarized
```
|-PIPELINE_OUTPUT-|
|-enum------------|
| U8              |
```
---
`FPS` enum:
`0x00`: 13
`0x01`: 72
```
|-FPS--|
|-enum-|
| U8   |
```
## commands
---
`log_set_level` command
**request**
```
|-head----------------------------------|-data[0]---|
| request id | cmd id | reserved | size | log level |
|------------|--------|----------|------|-----------|
| U8         | 0x10   | U8       | 0x01 | U8        | 
```
**response**
```
|-head----------------------------------|
| request id | cmd id | complete | size |
|------------|--------|----------|------|
| U8         | 0x10   | COMPLETE | 0x00 |
```
---
`camera_request_capture` command
**request**
```
|-head----------------------------------|
| request id | cmd id | reserved | size |
|------------|--------|----------|------|
| U8         | 0x20   | U8       | 0x00 |
```
**response**
```
|-head----------------------------------|
| request id | cmd id | complete | size |
|------------|--------|----------|------|
| U8         | 0x20   | COMPLETE | 0x00 |
```
---
`camera_request_transfer` command
**request**
```
|-head----------------------------------|
| request id | cmd id | reserved | size |
|------------|--------|----------|------|
| U8         | 0x21   | U8       | 0x00 |
```
**response**
```
|-head----------------------------------|
| request id | cmd id | complete | size |
|------------|--------|----------|------|
| U8         | 0x21   | COMPLETE | 0x00 |
```
---
`camera_set_whitebalance` command
**request**
```
|-head----------------------------------|-data[0:1]-|-data[2:3]-|-data[4:5]-|
| request id | cmd id | reserved | size | red       | green     | blue      |
|------------|--------|----------|------|-----------|-----------|-----------|
| U8         | 0x22   | U8       | 0x07 | U16       | U16       | U16       |
```
**response**
```
|-head----------------------------------|
| request id | cmd id | complete | size |
|------------|--------|----------|------|
| U8         | 0x22   | COMPLETE | 0x00 |
```
---
`camera_set_exposure` command
**request**
```
|-head----------------------------------|-data[0:1]-----|-data[1]--------|
| request id | cmd id | reserved | size | level integer | level fraction |
|------------|--------|----------|------|---------------|----------------|
| U8         | 0x23   | U8       | 0x03 | U16           | U8             |
```
**response**
```
|-head----------------------------------|
| request id | cmd id | complete | size |
|------------|--------|----------|------|
| U8         | 0x23   | COMPLETE | 0x00 |
```
---
`camera_set_gain` command
**request**
manual
```
|-head----------------------------------|-data[0]-|-data[1]-|
| request id | cmd id | reserved | size | level   | band    |
|------------|--------|----------|------|---------|---------|
| U8         | 0x24   | U8       | 0x02 | U8      | U8      |
```
**response**
```
|-head----------------------------------|
| request id | cmd id | complete | size |
|------------|--------|----------|------|
| U8         | 0x24   | COMPLETE | 0x00 |
```
---
`camera_set_fps` command
**request**
manual
```
|-head----------------------------------|-data[0]-|
| request id | cmd id | reserved | size | fps     |
|------------|--------|----------|------|---------|
| U8         | 0x25   | U8       | 0x01 | FPS     |
```
**response**
```
|-head----------------------------------|
| request id | cmd id | complete | size |
|------------|--------|----------|------|
| U8         | 0x25   | COMPLETE | 0x00 |
```
---
`network_get_config` command
**request**
```
|-head----------------------------------|
| request id | cmd id | reserved | size |
|------------|--------|----------|------|
| U8         | 0x30   | U8       | 0x00 |
```
**response**
```
|-head----------------------------------|-data[0:5]---|-data[6:9]--|-data[10:13]-|-data[14:17]-|
| request id | cmd id | complete | size | Mac Address | Ip Address | Netmask     | Gateway     |
|------------|--------|----------|------|-------------|------------|-------------|-------------|
| U8         | 0x30   | COMPLETE | 0x12 | MAC         | IPV4       | IPV4        | IPV4        |
```
---
`network_set_config` command
**request**
```
|-head----------------------------------|-data[0:5]---|-data[6:9]--|-data[10:13]-|-data[14:17]-|
| request id | cmd id | reserved | size | Mac Address | Ip Address | Netmask     | Gateway     |
|------------|--------|----------|------|-------------|------------|-------------|-------------|
| U8         | 0x31   | U8       | 0x12 | MAC         | IPV4       | IPV4        | IPV4        |
```
**response**
```
|-head----------------------------------|
| request id | cmd id | complete | size |
|------------|--------|----------|------|
| U8         | 0x31   | COMPLETE | 0x00 |
```
---
`network_persist_config` command
**request**
```
|-head----------------------------------|
| request id | cmd id | reserved | size |
|------------|--------|----------|------|
| U8         | 0x32   | U8       | 0x00 |
```
**response**
```
|-head----------------------------------|
| request id | cmd id | complete | size |
|------------|--------|----------|------|
| U8         | 0x32   | COMPLETE | 0x00 |
```
---
`calibration_load_camera_matrix` command
**request**
```
|-head----------------------------------|
| request id | cmd id | reserved | size |
|------------|--------|----------|------|
| U8         | 0x40   | U8       | 0x00 |
```
**response**
```
|-head----------------------------------|-data[0:35]----|
| request id | cmd id | complete | size | camera matrix |
|------------|--------|----------|------|---------------|
| U8         | 0x40   | COMPLETE | 0x24 | MTX_3x3       |
```
---
`calibration_store_camera_matrix` command
**request**
```
|-head----------------------------------|-data[0:35]----|
| request id | cmd id | reserved | size | camera matrix |
|------------|--------|----------|------|---------------|
| U8         | 0x41   | U8       | 0x24 | MTX_3x3       |
```
**response**
```
|-head----------------------------------|
| request id | cmd id | complete | size |
|------------|--------|----------|------|
| U8         | 0x41   | COMPLETE | 0x00 |
```
---
`calibration_load_distortion_coefficients` command
**request**
```
|-head----------------------------------|
| request id | cmd id | reserved | size |
|------------|--------|----------|------|
| U8         | 0x42   | U8       | 0x00 |
```
**response**
```
|-head----------------------------------|-data[0:19]--------------|
| request id | cmd id | complete | size | distortion coefficients |
|------------|--------|----------|------|-------------------------|
| U8         | 0x42   | COMPLETE | 0x14 | MTX_1x5                 |
```
---
`calibration_store_distortion_coefficients` command
**request**
```
|-head----------------------------------|-data[0:19]--------------|
| request id | cmd id | reserved | size | distortion coefficients |
|------------|--------|----------|------|-------------------------|
| U8         | 0x43   | U8       | 0x14 | MTX_1x5                 |
```
**response**
```
|-head----------------------------------|
| request id | cmd id | complete | size |
|------------|--------|----------|------|
| U8         | 0x43   | COMPLETE | 0x00 |
```
---
`calibration_load_rotation_matrix` command
**request**
```
|-head----------------------------------|
| request id | cmd id | reserved | size |
|------------|--------|----------|------|
| U8         | 0x44   | U8       | 0x00 |
```
**response**
```
|-head----------------------------------|-data[0:35]------|
| request id | cmd id | complete | size | rotation matrix |
|------------|--------|----------|------|-----------------|
| U8         | 0x44   | COMPLETE | 0x24 | MTX_3x3         |
```
---
`calibration_store_rotation_matrix` command
**request**
```
|-head----------------------------------|-data[0:35]------|
| request id | cmd id | reserved | size | rotation matrix |
|------------|--------|----------|------|-----------------|
| U8         | 0x45   | U8       | 0x14 | MTX_3x3         |
```
**response**
```
|-head----------------------------------|
| request id | cmd id | complete | size |
|------------|--------|----------|------|
| U8         | 0x45   | COMPLETE | 0x00 |
```
---
`calibration_load_translation_vector` command
**request**
```
|-head----------------------------------|
| request id | cmd id | reserved | size |
|------------|--------|----------|------|
| U8         | 0x46   | U8       | 0x00 |
```
**response**
```
|-head----------------------------------|-data[0:11]---------|
| request id | cmd id | complete | size | translation vector |
|------------|--------|----------|------|--------------------|
| U8         | 0x46   | COMPLETE | 0x14 | MTX_1x3            |
```
---
`calibration_store_translation_vector command
**request**
```
|-head----------------------------------|-data[0:11]---------|
| request id | cmd id | reserved | size | translation vector |
|------------|--------|----------|------|--------------------|
| U8         | 0x47   | U8       | 0x0b | MTX_1x3            |
```
**response**
```
|-head----------------------------------|
| request id | cmd id | complete | size |
|------------|--------|----------|------|
| U8         | 0x47   | COMPLETE | 0x00 |
```
---
`pipeline_set_input` command
**request**
```
|-head----------------------------------|-data[0]--------|
| request id | cmd id | reserved | size | pipeline input |
|------------|--------|----------|------|----------------|
| U8         | 0x50   | U8       | 0x01 | PIPELINE_INPUT |
```
**response**
```
|-head----------------------------------|
| request id | cmd id | complete | size |
|------------|--------|----------|------|
| U8         | 0x50   | COMPLETE | 0x00 |
```
---
`pipeline_set_output` command
**request**
```
|-head----------------------------------|-data[0]---------|
| request id | cmd id | reserved | size | pipeline output |
|------------|--------|----------|------|-----------------|
| U8         | 0x51   | U8       | 0x01 | PIPELINE_OUTPUT |
```
**response**
```
|-head----------------------------------|
| request id | cmd id | complete | size |
|------------|--------|----------|------|
| U8         | 0x51   | COMPLETE | 0x00 |
```
---
`pipeline_set_binarization_threshold` command
**request**
```
|-head----------------------------------|-data[0]---|
| request id | cmd id | reserved | size | threshold |
|------------|--------|----------|------|-----------|
| U8         | 0x52   | U8       | 0x01 | U8        |
```
**response**
```
|-head----------------------------------|
| request id | cmd id | complete | size |
|------------|--------|----------|------|
| U8         | 0x52   | COMPLETE | 0x00 |
```
---
`strobe_enable_pulse` command
**request**
```
|-head----------------------------------|-data[0]-|
| request id | cmd id | reserved | size | enable  |
|------------|--------|----------|------|---------|
| U8         | 0x60   | U8       | 0x01 | bool    |
```
**response**
```
|-head----------------------------------|
| request id | cmd id | complete | size |
|------------|--------|----------|------|
| U8         | 0x60   | COMPLETE | 0x00 |
```
---
`strobe_set_on_delay` command
**request**
```
|-head----------------------------------|-data[0:3]----|
| request id | cmd id | reserved | size | delay cycles |
|------------|--------|----------|------|--------------|
| U8         | 0x61   | U8       | 0x03 | U32          |
```
**response**
```
|-head----------------------------------|
| request id | cmd id | complete | size |
|------------|--------|----------|------|
| U8         | 0x61   | COMPLETE | 0x00 |
```
---
`strobe_set_hold_time` command
**request**
```
|-head----------------------------------|-data[0:3]---|
| request id | cmd id | reserved | size | hold cycles |
|------------|--------|----------|------|-------------|
| U8         | 0x62   | U8       | 0x03 | U32         |
```
**response**
```
|-head----------------------------------|
| request id | cmd id | complete | size |
|------------|--------|----------|------|
| U8         | 0x62   | COMPLETE | 0x00 |
```
---
`strobe_enable_constant` command
**request**
```
|-head----------------------------------|-data[0]-|
| request id | cmd id | reserved | size | enable  |
|------------|--------|----------|------|---------|
| U8         | 0x63   | U8       | 0x01 | bool    |
```
**response**
```
|-head----------------------------------|
| request id | cmd id | complete | size |
|------------|--------|----------|------|
| U8         | 0x63   | COMPLETE | 0x00 |
```
