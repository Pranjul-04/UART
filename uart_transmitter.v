module uart_transmitter(
	input clk, reset, wr_enb, tx_enb,
	input [7:0] data_in,
	output reg tx_serial_data,
	output busy);

	// UART transmitter states
	parameter IDLE  = 3'b000;
	parameter START = 3'b001;
	parameter DATA  = 3'b010;
	parameter PARITY= 3'b011;
	parameter STOP  = 3'b100;

	reg [2:0] index; // Data bit index counter
	reg [2:0] state = IDLE; // Current transmitter state
	reg parity_bit; // Stored parity bit

	assign busy = (state != IDLE); // Indicates transmitter is active

	// Transmitter sequential logic
	always @(posedge clk) begin

		// Reset transmitter
		if(reset) begin
			state <= IDLE;

			// UART idle line remains high
			tx_serial_data <= 1'b1;
			index <= 0;
		end

		else begin

			case(state)

				// Waiting for new data
				IDLE: begin
							tx_serial_data <= 1'b1;

							// Load data when write is enabled
							if(wr_enb) begin

							    // Calculate even parity	
								parity_bit <= ^data_in;  // even parity
								index <= 0;
								state <= START;
							end
						end

				// Send start bit
				START: begin
							if(tx_enb) begin

								// Start bit is always logic 0
								tx_serial_data <= 1'b0;
								state <= DATA;
							end
						 end

				// Send 8 data bits
				DATA: begin
							if(tx_enb) begin
								
								// Transmit current data bit
								tx_serial_data <= data_in[index];
								index <= index + 1'b1;

								 // After last bit move to parity
								if(index == 3'b111)
									state <= PARITY;
							end
						end

				// Send parity bit
				PARITY: begin
							if(tx_enb) begin
								tx_serial_data <= parity_bit;
								state <= STOP;
							end
						  end

				// Send stop bit
				STOP: begin
							if(tx_enb) begin

								// Stop bit is logic 1
								tx_serial_data <= 1'b1;
								state <= IDLE;
							end
						end

			endcase

		end
	end

endmodule
