`timescale 1ns/1ps

module UART_tb;

	reg clk;
	reg reset;
	reg tx_start;
	reg [7:0] Data_in;
	wire [7:0] Data_out;
	wire rx_ready;

	// Instantiate the Unit Under Test (UUT)
	UART_top DUT(
		.clk(clk),
		.reset(reset),
		.tx_start(tx_start),
		.Data_in(Data_in),
		.Data_out(Data_out),
		.rx_ready(rx_ready)
	);

	// 1. CLOCK GENERATOR (50 MHz)
	initial begin
		clk = 0;
		forever #10 clk = ~clk; // 20ns period
	end

	// 2. WAVEFORM DUMP
	initial begin
		$dumpfile("uart_waveform.vcd");
		$dumpvars(0, UART_tb);
	end

	// 3. THE SELF-CHECKING TASK
	task send_and_check(input [7:0] test_val);
		begin
			$display("[%0t ns] -----------------------------------------", $time);
			$display("[%0t ns] INITIATING SEND: %h", $time, test_val);
			
			// 1. Put data on the bus
			Data_in = test_val;
			
			// 2. Pulse the start signal
			@(posedge clk);
			tx_start = 1;
			@(posedge clk);
			tx_start = 0;
			
			// 3. Smart wait for completion flag
			wait(rx_ready == 1'b1);
			@(posedge clk); 

			// 4. Monitor and Check Results
			if (Data_out === test_val) begin
				$display("[%0t ns] [PASS] SENT: %h | RECEIVED: %h", $time, test_val, Data_out);
			end else begin
				$display("[%0t ns] [FAIL] SENT: %h | RECEIVED: %h", $time, test_val, Data_out);
				$display("         -> ERROR: Mismatch detected!");
			end
			
			// Short cooldown before next transmission
			#1000; 
		end
	endtask

	// 4. MAIN TEST SEQUENCE
	initial begin
		// Initialize Inputs
		Data_in = 8'h00;
		tx_start = 0;
		reset = 1; // Assert reset
		
		#100; 
		reset = 0; // Release reset
		#100;

		// Run through test cases
		send_and_check(8'hA5);  // Alternating bits (10100101)
		send_and_check(8'h3C);  // Nibble pattern (00111100)
		send_and_check(8'hF0);  // Half-byte pattern (11110000)
		send_and_check(8'h55);  // Alternating bits (01010101)

		$display("[%0t ns] -----------------------------------------", $time);
		$display("[%0t ns] SIMULATION COMPLETE.\n", $time);
		
		$finish;
	end

endmodule