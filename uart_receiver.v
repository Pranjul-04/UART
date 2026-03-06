module uart_receiver(
	input clk,
	input reset,
	input rx_enb,
	input ready_clr,
	input rx_serial_data,
	
	output reg ready,
	output reg [7:0] data_out,
	output reg parity_error
);

	parameter START  = 2'b00;
	parameter DATA   = 2'b01;
	parameter PARITY = 2'b10;
	parameter STOP   = 2'b11;

	reg [1:0] state = START;
	reg [3:0] sample = 0;
	reg [2:0] index = 0;
	reg [7:0] temp = 0;

	reg received_parity;

	wire parity_calc;
	assign parity_calc = ^temp;

	always @(posedge clk or posedge reset) begin

		if(reset) begin
			ready <= 0;
			data_out <= 0;
			parity_error <= 0;
			state <= START;
			sample <= 0;
			index <= 0;
			temp <= 0;
		end

		else begin

			if(ready_clr)
				ready <= 0;

			if(rx_enb) begin

				case(state)

					START: begin
						if(rx_serial_data == 0)
							sample <= sample + 1'b1;

						if(sample == 4'd15) begin
							state <= DATA;
							sample <= 0;
							index <= 0;
							temp <= 0;
						end
					end

					DATA: begin
								sample <= sample + 1'b1;
								if(sample == 4'd8)
									temp[index] <= rx_serial_data;
								if(sample == 4'd15) begin
									sample <= 0;
									if(index == 3'b111)
										state <= PARITY;
									else
										index <= index + 1'b1;
								end
							end

					PARITY: begin
						sample <= sample + 1'b1;

						if(sample == 4'd8)
							received_parity <= rx_serial_data;

						if(sample == 4'd15) begin
							sample <= 0;
							state <= STOP;
						end
					end

					STOP: begin
						sample <= sample + 1'b1;

						if(sample == 4'd15) begin
							data_out <= temp;
							ready <= 1'b1;

							if(parity_calc != received_parity)
								parity_error <= 1;
							else
								parity_error <= 0;

							state <= START;
							sample <= 0;
						end
					end

				endcase

			end
		end
	end

endmodule