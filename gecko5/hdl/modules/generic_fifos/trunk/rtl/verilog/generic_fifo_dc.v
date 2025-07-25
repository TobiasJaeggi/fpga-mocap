/////////////////////////////////////////////////////////////////////
////                                                             ////
////  Universal FIFO Single Clock                                ////
////                                                             ////
////                                                             ////
////  Author: Rudolf Usselmann                                   ////
////          rudi@asics.ws                                      ////
////                                                             ////
////                                                             ////
////  D/L from: http://www.opencores.org/cores/generic_fifos/    ////
////                                                             ////
/////////////////////////////////////////////////////////////////////
////                                                             ////
//// Copyright (C) 2000-2002 Rudolf Usselmann                    ////
////                         www.asics.ws                        ////
////                         rudi@asics.ws                       ////
////                                                             ////
//// This source file may be used and distributed without        ////
//// restriction provided that this copyright statement is not   ////
//// removed from the file and that any derivative work contains ////
//// the original copyright notice and the associated disclaimer.////
////                                                             ////
////     THIS SOFTWARE IS PROVIDED ``AS IS'' AND WITHOUT ANY     ////
//// EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED   ////
//// TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS   ////
//// FOR A PARTICULAR PURPOSE. IN NO EVENT SHALL THE AUTHOR      ////
//// OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,         ////
//// INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES    ////
//// (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE   ////
//// GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR        ////
//// BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF  ////
//// LIABILITY, WHETHER IN  CONTRACT, STRICT LIABILITY, OR TORT  ////
//// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT  ////
//// OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE         ////
//// POSSIBILITY OF SUCH DAMAGE.                                 ////
////                                                             ////
/////////////////////////////////////////////////////////////////////

//  CVS Log
//
//  $Id: generic_fifo_dc.v,v 1.1.1.1 2002-09-25 05:42:02 rudi Exp $
//
//  $Date: 2002-09-25 05:42:02 $
//  $Revision: 1.1.1.1 $
//  $Author: rudi $
//  $Locker:  $
//  $State: Exp $
//
// Change History:
//               $Log: not supported by cvs2svn $
//
//
//
//
//
//
//
//
//
//

`include "timescale.v"

/*

Description
===========

I/Os
----
rd_clk	Read Port Clock
wr_clk	Write Port Clock
rst	low active, either sync. or async. master reset (see below how to select)
clr	synchronous clear (just like reset but always synchronous), high active
re	read enable, synchronous, high active
we	read enable, synchronous, high active
din	Data Input
dout	Data Output

full	Indicates the FIFO is full (driven at the rising edge of wr_clk)
empty	Indicates the FIFO is empty (driven at the rising edge of rd_clk)

full_n	Indicates if the FIFO has space for N entries (driven of wr_clk)
empty_n	Indicates the FIFO has at least N entries (driven of rd_clk)

level		indicates the FIFO level:
		2'b00	0-25%	 full
		2'b01	25-50%	 full
		2'b10	50-75%	 full
		2'b11	%75-100% full

Status Timing
-------------
All status outputs are registered. They are asserted immediately
as the full/empty condition occurs, however, there is a 2 cycle
delay before they are de-asserted once the condition is not true
anymore.

Parameters
----------
The FIFO takes 3 parameters:
dw	Data bus width
aw	Address bus width (Determines the FIFO size by evaluating 2^aw)
n	N is a second status threshold constant for full_n and empty_n
	If you have no need for the second status threshold, do not
	connect the outputs and the logic should be removed by your
	synthesis tool.

Synthesis Results
-----------------
In a Spartan 2e a 8 bit wide, 8 entries deep FIFO, takes 85 LUTs and runs
at about 116 MHz (IO insertion disabled). The registered status outputs
are valid after 2.1NS, the combinatorial once take out to 6.5 NS to be
available.

Misc
----
This design assumes you will do appropriate status checking externally.

IMPORTANT ! writing while the FIFO is full or reading while the FIFO is
empty will place the FIFO in an undefined state.

*/


// Selecting Sync. or Async Reset
// ------------------------------
// Uncomment one of the two lines below. The first line for
// synchronous reset, the second for asynchronous reset

//`define DC_FIFO_ASYNC_RESET				// Uncomment for Syncr. reset
`define DC_FIFO_ASYNC_RESET	or negedge rst		// Uncomment for Async. reset


module generic_fifo_dc(rd_clk, wr_clk, rst, clr, din, we, dout, re,
			full, empty, full_n, empty_n, level );

parameter dw=8;
parameter aw=8;
parameter n=32;
parameter max_size = 1<<aw;

input			rd_clk, wr_clk, rst, clr;
input	[dw-1:0]	din;
input			we;
output	[dw-1:0]	dout;
input			re;
output			full; 
output			empty;
output			full_n;
output			empty_n;
output	[1:0]		level;

////////////////////////////////////////////////////////////////////
//
// Local Wires
//

reg	[aw:0]		wp;
wire	[aw:0]		wp_pl1;
reg	[aw:0]		rp;
wire	[aw:0]		rp_pl1;
reg	[aw:0]		wp_s, rp_s;
wire	[aw:0]		diff;
reg	[aw:0]		diff_r1, diff_r2;
reg			re_r, we_r;
reg			full, empty, full_n, empty_n;
reg	[1:0]		level;

////////////////////////////////////////////////////////////////////
//
// Memory Block
//

generic_dpram  #(aw,dw) u0(
	.rclk(		rd_clk		),
	.rrst(		!rst		),
	.rce(		1'b1		),
	.oe(		1'b1		),
	.raddr(		rp[aw-1:0]	),
	.do(		dout		),
	.wclk(		wr_clk		),
	.wrst(		!rst		),
	.wce(		1'b1		),
	.we(		we		),
	.waddr(		wp[aw-1:0]	),
	.di(		din		)
	);

////////////////////////////////////////////////////////////////////
//
// Read/Write Pointers Logic
//

always @(posedge wr_clk `DC_FIFO_ASYNC_RESET)
	if(!rst)	wp <= #1 {aw+1{1'b0}};
	else
	if(clr)		wp <= #1 {aw+1{1'b0}};
	else
	if(we)		wp <= #1 wp_pl1;

assign wp_pl1 = wp + { {aw{1'b0}}, 1'b1};

always @(posedge rd_clk `DC_FIFO_ASYNC_RESET)
	if(!rst)	rp <= #1 {aw+1{1'b0}};
	else
	if(clr)		rp <= #1 {aw+1{1'b0}};
	else
	if(re)		rp <= #1 rp_pl1;

assign rp_pl1 = rp + { {aw{1'b0}}, 1'b1};

////////////////////////////////////////////////////////////////////
//
// Synchronization Logic
//

// write pointer
always @(posedge rd_clk)	wp_s <= #1 wp;

// read pointer
always @(posedge wr_clk)	rp_s <= #1 rp;

////////////////////////////////////////////////////////////////////
//
// Registered Full & Empty Flags
//

always @(posedge rd_clk)
	empty <= #1 (wp_s == rp) | (re & (wp_s == rp_pl1));

always @(posedge wr_clk)
	full <= #1 ((wp[aw-1:0] == rp_s[aw-1:0]) & (wp[aw] != rp_s[aw])) |
	(we & (wp_pl1[aw-1:0] == rp_s[aw-1:0]) & (wp_pl1[aw] != rp_s[aw]));

////////////////////////////////////////////////////////////////////
//
// Registered Full_n & Empty_n Flags
//

assign diff = wp-rp;

always @(posedge rd_clk)
	re_r <= #1 re;

always @(posedge rd_clk)
	diff_r1 <= #1 diff;

always @(posedge rd_clk)
	empty_n <= #1 (diff_r1 < n) | ((diff_r1==n) & (re | re_r));

always @(posedge wr_clk)
	we_r <= #1 we;

always @(posedge wr_clk)
	diff_r2 <= #1 diff;

always @(posedge wr_clk)
	full_n <= #1 (diff_r2 > max_size-n) | ((diff_r2==max_size-n) & (we | we_r));

always @(posedge wr_clk)
	level <= #1 {2{diff[aw]}} | diff[aw-1:aw-2];


////////////////////////////////////////////////////////////////////
//
// Sanity Check
//

// synopsys translate_off
always @(posedge wr_clk)
	if(we & full)
		$display("%m WARNING: Writing while fifo is FULL (%t)",$time);

always @(posedge rd_clk)
	if(re & empty)
		$display("%m WARNING: Reading while fifo is EMPTY (%t)",$time);
// synopsys translate_on

endmodule

