/*******************************************************************************
 * Copyright (c) 2012, Lingkan Gong
 * All rights reserved.
 * 
 * Redistribution and use in source and binary forms, with or without 
 * modification, are permitted provided that the following conditions are met:
 * 
 *  * Redistributions of source code must retain the above copyright notice, 
 *    this list of conditions and the following disclaimer.
 *
 *  * Redistributions in binary form must reproduce the above copyright notice, 
 *    this list of conditions and the following disclaimer in the documentation 
 *    and/or other materials provided with the distribution.
 *
 *  * Neither the name of the copyright holder(s) nor the names of its
 *    contributors may be used to endorse or promote products derived from this 
 *    software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL <COPYRIGHT HOLDER> BE LIABLE FOR ANY
 * DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
*******************************************************************************/

`ifndef RSV_MONITOR_SVH
`define RSV_MONITOR_SVH

//-------------------------------------------------------------------------
//-------------------------------------------------------------------------

class rsv_monitor#(type IF=virtual interface null_if) extends rsv_monitor_base;

	//---------------------------------------------------------------------
	// virtual interface(s)
	//---------------------------------------------------------------------
	
	IF mon_vi;
	virtual function void register_if(IF mon_);
		mon_vi = mon_;
	endfunction : register_if

	//---------------------------------------------------------------------
	// configuration table and parameter(s)
	//---------------------------------------------------------------------
	
	protected int is_record_trans = 0;
	protected string rr_inst = "";
	`ovm_component_param_utils_begin(rsv_monitor#(IF))
		`ovm_field_int(is_record_trans, OVM_ALL_ON)
		`ovm_field_string(rr_inst, OVM_ALL_ON)
	`ovm_component_utils_end

	//---------------------------------------------------------------------
	// constructor, build(), connect() & other ovm phase(s)
	//---------------------------------------------------------------------
	
	function new (string name, ovm_component parent);
		super.new(name, parent);
	endfunction : new

	virtual function void build();
		super.build();
		`get_config_interface(rsv_if_wrapper#(IF),"mon_tag",mon_vi)
	endfunction : build

	//---------------------------------------------------------------------
	// run(), member tasks & member variables
	//---------------------------------------------------------------------
	
	integer sbt_stream_h=0, sbt_trans_h=0;
	integer usr_stream_h=0, usr_trans_h=0;
	
	extern virtual task print_record_trans(rsv_trans tr);
	extern virtual protected task visualize_sbt_transaction(rsv_sbt_trans tr);
	extern virtual protected task visualize_usr_transaction(rsv_usr_trans tr);
	
	// The run task collect signal-level manipulation on the i/o of the
	// region and write transactions to the analysis port of the parent
	// artifact

	virtual task run();
	
		sbt_stream_h = $create_transaction_stream( {"..",get_full_name(),".","sbt_trans"} );
		usr_stream_h = $create_transaction_stream( {"..",get_full_name(),".","usr_trans"} );
	
		fork
			collect_unload_transaction();
			collect_activate_transaction();
		join_none
	endtask : run

	virtual protected task collect_unload_transaction();
		`ovm_warning("ReSim", "Using the default monitor")
	endtask : collect_unload_transaction

	virtual protected task collect_activate_transaction();
		`ovm_warning("ReSim", "Using the default monitor")
	endtask : collect_activate_transaction

endclass : rsv_monitor

task rsv_monitor::print_record_trans(rsv_trans tr);
	
	// The print_record_trans task performs transaction visualization operations 
	// according to the incomming transaction. 
	
	rsv_sbt_trans sbt_tr;
	rsv_usr_trans usr_tr;

	fork
		begin if ( $cast( sbt_tr, tr ) && is_record_trans) visualize_sbt_transaction(sbt_tr); end
		begin if ( $cast( usr_tr, tr ) && is_record_trans) visualize_usr_transaction(usr_tr); end
		/* if both casts fails, do nothing */
	join

endtask : print_record_trans

task rsv_monitor::visualize_sbt_transaction(rsv_sbt_trans tr);

	// This task visualize the SBT transactions and records them in ModelSim.
	// You can use "add wave" command to view them on the waveform window. Please
	// refer to ModelSim User Manual for details.
	// 
	// The default implementation records all incomming transactions if the
	// "tr.sensitivity_level" is set. Users can overide this behavior by deriving
	// a new class.
	
	`print_info("ReSim", tr.conv2str(), tr.sensitivity_level);
	
	if (tr.sensitivity_level != OVM_FULL) begin
		integer this_trans_h = 0;
		
		if (tr.op == SYNC) begin
			`check_fatal(sbt_trans_h == 0, "@SYNC, SBT transaction stream should not exist");
			sbt_trans_h = $begin_transaction(sbt_stream_h, "PARTIAL_RECONFIGURATION", tr.event_time);
		end

		`check_fatal(sbt_trans_h != 0, "@PARTIAL_RECONFIGURATION, SBT transaction stream should exist");

		this_trans_h = $begin_transaction(sbt_stream_h, $psprintf("%s",tr.op), tr.event_time, sbt_trans_h);
		$add_attribute(this_trans_h, tr.conv2str(), "OP");
		$end_transaction(this_trans_h, $realtime, 1);

		if (tr.op == DESYNC) begin
			`check_fatal(sbt_trans_h != 0, "@DESYNC, SBT transaction stream should exist");
			$end_transaction(sbt_trans_h, $realtime, 1); sbt_trans_h = 0;
		end
	end

endtask : visualize_sbt_transaction

task rsv_monitor::visualize_usr_transaction(rsv_usr_trans tr);

	// This task visualize the USR transactions and records them in ModelSim. 
	// The default implementation simply records all transactions. 

	`print_info("ReSim", tr.conv2str(), tr.sensitivity_level);
	
	if (tr.sensitivity_level != OVM_FULL) begin

		usr_trans_h = $begin_transaction(usr_stream_h, $psprintf("%s",tr.op), tr.event_time);
		$add_attribute(usr_trans_h, tr.conv2str(), "OP");
		$end_transaction(usr_trans_h, $realtime, 1);
	end

endtask : visualize_usr_transaction
	
`endif // RSV_MONITOR_SVH