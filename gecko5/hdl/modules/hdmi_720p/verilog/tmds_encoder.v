module tmdsEncoder ( input wire       clock,
                                      blank,
                     input wire [7:0] data,
                     input wire [1:0] sync,
                     output reg [9:0] encoded );
  wire [8:0] s_xored, s_xnored, s_dataWord;
  wire [3:0] s_nrOfOnes;
  reg [3:0] s_dcBias;
  wire [3:0] s_dataWordDisparity;
  
  assign s_xored[0] = data[0];
  assign s_xored[1] = data[1] ^ s_xored[0];
  assign s_xored[2] = data[2] ^ s_xored[1];
  assign s_xored[3] = data[3] ^ s_xored[2];
  assign s_xored[4] = data[4] ^ s_xored[3];
  assign s_xored[5] = data[5] ^ s_xored[4];
  assign s_xored[6] = data[6] ^ s_xored[5];
  assign s_xored[7] = data[7] ^ s_xored[6];
  assign s_xored[8] = 1'b1;
  
  assign s_xnored[0] = data[0];
  assign s_xnored[1] = ~(data[1] ^ s_xnored[0]);
  assign s_xnored[2] = ~(data[2] ^ s_xnored[1]);
  assign s_xnored[3] = ~(data[3] ^ s_xnored[2]);
  assign s_xnored[4] = ~(data[4] ^ s_xnored[3]);
  assign s_xnored[5] = ~(data[5] ^ s_xnored[4]);
  assign s_xnored[6] = ~(data[6] ^ s_xnored[5]);
  assign s_xnored[7] = ~(data[7] ^ s_xnored[6]);
  assign s_xnored[8] = 1'b0;
  
  assign s_nrOfOnes = 4'b0+data[0]+data[1]+data[2]+data[3]+
                      data[4]+data[5]+data[6]+data[7];
  assign s_dataWord = ((s_nrOfOnes > 4)||((s_nrOfOnes == 4)&&(data[0] == 1'b0))) ? s_xnored : s_xored;
  
  reg [8:0] s_dataWordReg, s_invertedDataWordReg;
  reg       s_blankReg;
  reg [1:9] s_syncReg; 
  
  always @(posedge clock)
    begin
      s_dataWordReg         <= s_dataWord;
      s_invertedDataWordReg <= ~s_dataWord;
      s_blankReg            <= blank;
      s_syncReg             <= sync;
    end
  
  assign s_dataWordDisparity = 4'b1100+s_dataWordReg[0]+s_dataWordReg[1]+s_dataWordReg[2]+s_dataWordReg[3]+
                               s_dataWordReg[4]+s_dataWordReg[5]+s_dataWordReg[6]+s_dataWordReg[7];

  reg [8:0] s_dataWord1Reg, s_invertedDataWord1Reg;
  reg [3:0] s_s_dataWordDisparityReg;
  reg       s_blank1Reg;
  reg [1:9] s_sync1Reg; 
  
  always @(posedge clock)
    begin
      s_invertedDataWord1Reg   <= s_invertedDataWordReg;
      s_dataWord1Reg           <= s_dataWordReg;
      s_s_dataWordDisparityReg <= s_dataWordDisparity;
      s_blank1Reg              <= s_blankReg;
      s_sync1Reg               <= s_syncReg;
    end
    
  always @(posedge clock)
  begin
    if (s_blank1Reg == 1'b1)
      begin
        case (s_sync1Reg)
          2'b00   : encoded <= 10'b1101010100;
          2'b01   : encoded <= 10'b0010101011;
          2'b10   : encoded <= 10'b0101010100;
          default : encoded <= 10'b1010101011;
        endcase
        s_dcBias <= 4'b0000;
      end
    else
      begin
        if ((s_dcBias == 0)||(s_s_dataWordDisparityReg == 0))
          begin
            if (s_dataWord1Reg[8] == 1'b1)
              begin
                encoded <= {2'b01,s_dataWord1Reg[7:0]};
                s_dcBias <= s_dcBias + s_s_dataWordDisparityReg;
              end
            else
              begin
                encoded <= {2'b10,s_invertedDataWord1Reg[7:0]};
                s_dcBias <= s_dcBias - s_s_dataWordDisparityReg;
              end
          end
        else if (s_dcBias[3] == s_s_dataWordDisparityReg[3])
          begin
            encoded <= {1'b1,s_dataWord1Reg[8],s_invertedDataWord1Reg[7:0]};
            s_dcBias <= s_dcBias + s_dataWord1Reg[8] - s_s_dataWordDisparityReg;
          end
        else
          begin
            encoded <= {1'b0,s_dataWord1Reg};
            s_dcBias <= s_dcBias - s_invertedDataWord1Reg[8] + s_s_dataWordDisparityReg;
          end
      end
  end
endmodule
