module UART_top(
	input clk,
	input reset,
	input tx_start, 
	input [7:0] Data_in,
	output [7:0] Data_out,
	output rx_ready 
);

	wire tx_enb_top;
	wire rx_enb_top;
	wire serial_data;

	wire ready;
	wire parity_error;

	reg wr_enb;
	reg ready_clr;

	reg [2:0] state, next_state;

	parameter IDLE  = 3'b000;
	parameter SEND  = 3'b001;
	parameter WAIT  = 3'b010;
	parameter CHECK = 3'b011;
	parameter CLEAR = 3'b100;

	baud_rate_generator baud_rate(
		.clk(clk),
		.rst(reset), 
		.tx_enb(tx_enb_top),
		.rx_enb(rx_enb_top)
	);

	uart_transmitter tx(
		.clk(clk),
		.reset(reset),
		.wr_enb(wr_enb),
		.tx_enb(tx_enb_top),
		.data_in(Data_in),
		.tx_serial_data(serial_data),
		.busy()
	);

	uart_receiver rx(
		.clk(clk),
		.reset(reset),
		.rx_enb(rx_enb_top),
		.ready_clr(ready_clr),
		.rx_serial_data(serial_data),
		.ready(ready),
		.data_out(Data_out),
		.parity_error(parity_error)
	);

	assign rx_ready = ready;

	always @(posedge clk or posedge reset) begin
		if(reset)
			state <= IDLE;
		else
			state <= next_state;
	end

	always @(*) begin
		next_state = state;
		wr_enb = 0;
		ready_clr = 0;

		case(state)
			IDLE: begin
				if(tx_start)
					next_state = SEND;
			end

			SEND: begin
				wr_enb = 1;
				next_state = WAIT;
			end

			WAIT: begin
				if(ready)
					next_state = CHECK;
			end

			CHECK: begin
				if(parity_error)
					next_state = SEND;    // retransmit
				else
					next_state = CLEAR;
			end

			CLEAR: begin
				ready_clr = 1;
				next_state = IDLE;
			end
			
			default: next_state = IDLE;
		endcase
	end
endmodule