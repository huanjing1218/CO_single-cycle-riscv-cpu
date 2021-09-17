// Please include verilog file if you write module in other file
module CPU(
    input clk,
    input rst,
    input [31:0] data_out,
    input [31:0] instr_out,
    output reg instr_read,
    output reg data_read,
    output reg [31:0] instr_addr,
    output reg [31:0] data_addr,
    output reg [3:0] data_write,
    output reg [31:0] data_in
);

reg [6:0] funct7, opcode;
reg [4:0] rs2, rs1, rd;
reg [2:0] funct3;
reg [31:0] imm;
reg [2:0] state;
reg [31:0] tmp [0:31];

integer i;

always @ (posedge clk or posedge rst) begin
	if(rst) begin
		instr_read <= 1;
		data_read <= 0;
		instr_addr <= 0;
		data_addr <= 0;
		data_write <= 0;
		data_in <= 0;
		funct7 <= 0;
		opcode <= 0;
		rs2 <= 0;
		rs1 <= 0;
		rd <= 0;
		funct3 <= 0;
		imm	<= 0;
		state <= 0;
		for(i = 0; i < 32; i = i + 1)
			tmp[i] = 0;
	end
	else begin
		tmp[0] <= 0;
		if(instr_read) begin
			state <= 0;
			instr_read <= 0;
			data_read <= 0;
			data_write <= 0;
		end
		else begin
			case (state)
				3'd0: begin					
					state <= 1;
					instr_read <= 0;
					opcode <= instr_out[6:0];
					case (instr_out[6:0])
						7'b0110011: begin
							funct7 <= instr_out[31:25];
							rs2 <= instr_out[24:20];
							rs1 <= instr_out[19:15];
							funct3 <= instr_out[14:12];
							rd <= instr_out[11:7];				
						end // R-type
						7'b0000011, 7'b0010011, 7'b1100111: begin
							imm <= $signed(instr_out[31:20]);
							rs1 <= instr_out[19:15];
							funct3 <= instr_out[14:12];
							rd <= instr_out[11:7];
						end // I-type
						7'b0100011: begin
							rs2 <= instr_out[24:20];
							rs1 <= instr_out[19:15];
							funct3 <= instr_out[14:12];
							imm <= $signed({instr_out[31:25], instr_out[11:7]}); 
						end // S-type
						7'b1100011: begin
							imm <= $signed({instr_out[31], instr_out[7], instr_out[30:25], instr_out[11:8], 1'b0});				
							rs2 <= instr_out[24:20];
							rs1 <= instr_out[19:15];
							funct3 <= instr_out[14:12];
						end // B-type
						7'b0010111, 7'b0110111: begin
							imm <= {instr_out[31:12], 12'b0};
							rd <= instr_out[11:7];				
						end // U-type
						7'b1101111: begin	
							imm <= $signed({instr_out[31], instr_out[19:12], instr_out[20], instr_out[30:21], 1'b0});
							rd <= instr_out[11:7];
						end // J-type
					endcase
				end
				3'd1: begin
					if(opcode == 7'b0000011) 
						state <= 4;
					else if(opcode == 7'b0100011)
						state <= 5;
					else 			 
						state <= 3;
						
					if(opcode != 7'b1100011 && opcode != 7'b1100111 && opcode != 7'b1101111)
						instr_addr <= instr_addr + 4;
					
					case (opcode)
						7'b0110011: begin
							case (funct3)
								3'b000: 
									if(funct7 == 7'b0000000)	
										tmp[rd] <= tmp[rs1] + tmp[rs2]; // ADD
									else 						
										tmp[rd] <= tmp[rs1] - tmp[rs2];	// SUB							
								3'b001: tmp[rd] <= $unsigned(tmp[rs1]) << tmp[rs2][4:0]; // SLL
								3'b010:	tmp[rd] <= $signed(tmp[rs1]) < $signed(tmp[rs2]) ? 1 : 0; // SLT
								3'b011:	tmp[rd] <= $unsigned(tmp[rs1]) < $unsigned(tmp[rs2]) ? 1 : 0; // SLTU
								3'b100:	tmp[rd] <= tmp[rs1] ^ tmp[rs2]; // XOR
								3'b101:
									if(funct7 == 7'b0000000)	
										tmp[rd] <= $unsigned(tmp[rs1]) >> tmp[rs2][4:0]; // SRL
									else 	
										tmp[rd] <= $signed(tmp[rs1]) >>> tmp[rs2][4:0];	 // SRA	 
								3'b110:	tmp[rd] <= tmp[rs1] | tmp[rs2];  // OR
								3'b111: tmp[rd] <= tmp[rs1] & tmp[rs2]; // AND
							endcase	
						end // R-type
						7'b0000011: begin
							data_addr <= tmp[rs1] + imm;
							data_read <= 1;
						end 
						7'b0010011: begin
							case (funct3)
								3'b000:	tmp[rd] <= tmp[rs1] + imm; // ADDI
								3'b010: tmp[rd] <= $signed(tmp[rs1]) < $signed(imm) ? 1 : 0; // SLTI
								3'b011: tmp[rd] <= $unsigned(tmp[rs1]) < $unsigned(imm) ? 1 : 0; // SLTIU
								3'b100:	tmp[rd] <= tmp[rs1] ^ imm; // XORI
								3'b110: tmp[rd] <= tmp[rs1] | imm; // ORI
								3'b111:	tmp[rd] <= tmp[rs1] & imm; // ANDI
								3'b001:	tmp[rd] <= $unsigned(tmp[rs1]) << imm[4:0]; // SLLI
								3'b101: 
									if(imm[10] == 0)	
										tmp[rd] <= $unsigned(tmp[rs1]) >> imm[4:0]; // SRLI
									else 		 		
										tmp[rd] <= $signed(tmp[rs1]) >>> imm[4:0]; // SRAI
							endcase
						end
						7'b1100111: begin
							tmp[rd] <= instr_addr + 4;
							instr_addr <= imm + tmp[rs1];
						end // I-type
						7'b0100011: begin
							data_addr <= tmp[rs1] + imm;
						end // S-type
						7'b1100011: begin
							case (funct3) 
								3'b000: instr_addr <= tmp[rs1] == tmp[rs2] ? instr_addr + imm : instr_addr + 4; // BEQ
								3'b001: instr_addr <= tmp[rs1] != tmp[rs2] ? instr_addr + imm : instr_addr + 4; // BNE	
								3'b100: instr_addr <= $signed(tmp[rs1]) <  $signed(tmp[rs2]) ? instr_addr + imm : instr_addr + 4; // BLT
								3'b101: instr_addr <= $signed(tmp[rs1]) >= $signed(tmp[rs2]) ? instr_addr + imm : instr_addr + 4; // BGE
								3'b110: instr_addr <= $unsigned(tmp[rs1]) <  $unsigned(tmp[rs2]) ? instr_addr + imm : instr_addr + 4; // BLTU
								3'b111: instr_addr <= $unsigned(tmp[rs1]) >= $unsigned(tmp[rs2]) ? instr_addr + imm : instr_addr + 4; // BGEU
							endcase
						end // B-type
						7'b0010111: begin
							tmp[rd] <= instr_addr + imm;				
						end
						7'b0110111: begin
							tmp[rd] <= imm;
						end // U-type
						7'b1101111: begin	
							tmp[rd] <= instr_addr + 4;
							instr_addr <= instr_addr + imm;
						end // J-type
					endcase	
				end
				3'd2: begin
					state <= 3;
					data_read <= 0;
					data_write <= 0;
					case (funct3)
						3'b010:	tmp[rd] <= data_out; // LW
						3'b000: tmp[rd] <= $signed(data_out[7:0]); // LB
						3'b001: tmp[rd] <= $signed(data_out[15:0]); // LH
						3'b100: tmp[rd] <= $unsigned(data_out[7:0]); // LBU
						3'b101: tmp[rd] <= $unsigned(data_out[15:0]); // LHU
					endcase
				end
				3'd3: begin
					state <= 0;
					instr_read <= 1;
					data_read <= 0;
					data_write <= 0;					
				end
				3'd4: begin
					data_read <= 0;
					state <= 2;
				end
				3'd5: begin
					state <= 3;
					case (funct3)
						3'b010: begin
							data_write <= 4'b1111;
							data_in <= tmp[rs2]; // SW
						end
						3'b000:	begin
							data_write <= 4'b0001 << data_addr[1:0];
							data_in <= tmp[rs2][7:0] << (data_addr[1:0] * 8); // SB
						end
						3'b001:	begin
							data_write <= 4'b0011 << data_addr[1:0];
							data_in <= tmp[rs2][15:0] << (data_addr[1:0] * 8); // SB
						end
					endcase
				end
			endcase				
		end			
	end
end

endmodule
