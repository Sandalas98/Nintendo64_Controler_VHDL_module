### VHDL module for Nintendo 64 controller

This VHDL module provide handlig official Nintendo 64 Controller. It pulls 20 times per second data from Nintendo 64 controller. The module returns 32 bits of data, which is represented by table:

| Bit number  | Description |
| ------------- | ------------- |
| 31  | A button  |
| 30  | B button  |
| 29  | Z button  |
| 28  | Start button  |
| 27  | D-pad UP  |
| 26  | D-pad DOWN  |
| 25  | D-pad LEFT  |
| 24  | D-pad RIGHT  |
| 23  | Reset (L+R+START) |
| 22  | Unknown, for standard controllers always 0  |
| 21  | L Button  |
| 20  | R Button  |
| 19  | C UP  |
| 18  | C DOWN  |
| 17  | C LEFT  |
| 16  | C RIGHT  |
| 15 - 8  | X axis  |
| 7 - 0  | Y axis  |

Axis bytes are represented in two's complement system.

This module has been prepared to work with 100 MHz clock. In case of other frequency, values must be changed.
