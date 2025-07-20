module processorId #( parameter [2:0] processorId = 1,
                      parameter [2:0] NumberOfProcessors = 1,
                      parameter ReferenceClockFrequencyInHz = 12000000 )
                    ( input wire         clock,
                                         reset,
                                         referenceClock,
                                         biosBypass,
                      output wire [31:0] procFreqId );

        function integer clog2;
          input integer value;
          begin
            for (clog2 = 0; value > 0 ; clog2= clog2 + 1)
            value = value >> 1;
          end
        endfunction

        localparam refClockDivideValue = ReferenceClockFrequencyInHz/1000; // corresponds to 1 ms
        localparam nrOfBits = clog2(refClockDivideValue);
  
        /* 
         * 
         * here we define a counter that "ticks" once a mili second
         *
         */
        reg [nrOfBits-1:0] s_miliSecCounterReg;
        wire s_miliSecCounterZero = s_miliSecCounterReg == 0 ? 1'b1 : 1'b0;
        wire [nrOfBits-1:0] s_miliSecCounterNext = (reset == 1'b1 || s_miliSecCounterZero == 1'b1) ? refClockDivideValue - 1 : s_miliSecCounterReg - 1;
  
        always @(posedge referenceClock) s_miliSecCounterReg <= s_miliSecCounterNext;
  
        /*
         *
         * here we define the decimal counter
         *
         */
        wire s_msecReset;
        synchroFlop msync ( .clockIn(referenceClock),
                            .clockOut(clock),
                            .reset(reset),
                            .D(s_miliSecCounterZero),
                            .Q(s_msecReset) );
  
        wire s_resetDecimalCounter = reset | s_msecReset;
        genvar n;
        wire [6:0] s_enables;
        wire [3:0] s_countValues [5:0];
        assign s_enables[0] = 1'b1;
		  generate
        for (n=0; n < 6; n = n + 1)
          begin : cnt
            decimalCounter dcount ( .clock(clock),
                                    .reset(s_resetDecimalCounter),
                                    .enable(s_enables[n]),
                                    .isNine(s_enables[n+1]),
                                    .countValue(s_countValues[n]) );
      	  end
        endgenerate
        /*
         *
         * finally we define the output value
         *
         */
        reg [31:0] s_procFreqIdReg;
        assign procFreqId = s_procFreqIdReg;
        always @(posedge clock)
            s_procFreqIdReg <= (reset == 1'b1) ? {25'd0,NumberOfProcessors,~biosBypass,processorId} :
                               (s_msecReset == 1'b1) ? {s_countValues[5],
                                                        s_countValues[4],
                                                        s_countValues[3],
                                                        s_countValues[2],
                                                        s_countValues[1],
                                                        s_countValues[0],
                                                        1'b0,
                                                        NumberOfProcessors,
                                                        ~biosBypass,
                                                        processorId} : s_procFreqIdReg;
endmodule
