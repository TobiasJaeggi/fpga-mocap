# `visionAddOn/hardware`
An addon for the [GECKO5Education](https://github.com/logisim-evolution/GECKO5Education) intended for IR based MoCap featuring
- STM32F767 with external RAM, EEPROM and external Watchdog
- Power Over Ethernet
- Connector for [KLT-E4MPF-OV9281 V4.2 NIR Camera](http://modulecamera.com)
- switchable 5V supply for external IR stroble LED
# known issues
## V1.0
### nINT/REFCLK0 does not output a clock
Pin 2 (LED2/nINIT/nPME/nINTSEL) on LAN87 needs a pulldown. Also, remove pulldown on LED1/nINT/nPME/REGOFF.
 
# Attribution
## Project Template
This project is based on the GECKO5 [addonTemplate](https://github.com/logisim-evolution/GECKO5Education/tree/main/kicad/addonTemplate)