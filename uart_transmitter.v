module uart_transmitter(
	input clk, reset, wr_enb, tx_enb,
	input [7:0] data_in,
	output reg tx_serial_data,
	output busy);
	
	parameter IDLE  = 3'b000;
	parameter START = 3'b001;
	parameter DATA  = 3'b010;
	parameter PARITY= 3'b011;
	parameter STOP  = 3'b100;

	reg [2:0] index;
	reg [2:0] state = IDLE;
	reg parity_bit;

	assign busy = (state != IDLE);

	always @(posedge clk) begin

		if(reset) begin
			state <= IDLE;
			tx_serial_data <= 1'b1;
			index <= 0;
		end

		else begin

			case(state)

				IDLE: begin
							tx_serial_data <= 1'b1;

							if(wr_enb) begin
								parity_bit <= ^data_in;  // even parity
								index <= 0;
								state <= START;
							end
						end

				START: begin
							if(tx_enb) begin
								tx_serial_data <= 1'b0;
								state <= DATA;
							end
						 end

				DATA: begin
							if(tx_enb) begin
								tx_serial_data <= data_in[index];
								index <= index + 1'b1;

								if(index == 3'b111)
									state <= PARITY;
							end
						end

				PARITY: begin
							if(tx_enb) begin
								tx_serial_data <= parity_bit;
								state <= STOP;
							end
						  end

				STOP: begin
							if(tx_enb) begin
								tx_serial_data <= 1'b1;
								state <= IDLE;
							end
						end

			endcase

		end
	end

endmodule