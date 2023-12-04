//This file was auto-corrected by findeclaration.exe on 25.5.2012 20:42:31
#define STATE_UNANCHORED 0
#define STATE_ANCHORED 1
#define STATE_SCREWED_CIRCUIT 2
#define STATE_WIRED 3
#define STATE_DISPLAY_IN 4

/obj/structure/computerframe
	density = FALSE
	anchored = FALSE
	name = "Computer-frame"
	icon = 'icons/obj/structures/machinery/stock_parts.dmi'
	icon_state = "0"
	var/state = STATE_UNANCHORED
	var/obj/item/circuitboard/computer/circuit = null
// weight = 1.0E8

/obj/structure/computerframe/get_examine_text(mob/user)
	. = ..()
	. += "It is [anchored ? "" : "un"]anchored."

	var/engi_examine_message = ""
	switch(state)
		if(STATE_UNANCHORED)
			engi_examine_message += "Its bolts can be [SPAN_HELPFUL("wrenched")] to the floor. "
			engi_examine_message += "It can be [SPAN_HELPFUL("welded")] apart."
		if(STATE_ANCHORED)
			if(circuit)
				engi_examine_message += "The circuit can be [SPAN_HELPFUL("screwed")] to the frame. "
			else
				engi_examine_message += "Its [SPAN_HELPFUL("circuit slot")] looks empty. "
			engi_examine_message += "Its bolts can be [SPAN_HELPFUL("wrenched")] loose."
		if(STATE_SCREWED_CIRCUIT)
			engi_examine_message += "It can be [SPAN_HELPFUL("wired")]. "
			engi_examine_message += "Its circuit board can be [SPAN_HELPFUL("unscrewed")] from the frame."
		if(STATE_WIRED)
			engi_examine_message += "You can insert [SPAN_HELPFUL("glass sheets")] to the frame. "
			engi_examine_message += "Its wiring can be [SPAN_HELPFUL("cut")] out."
		if(STATE_DISPLAY_IN)
			engi_examine_message += "The assembly can be finished with a [SPAN_HELPFUL("wrench")]. "
			engi_examine_message += "The display can be [SPAN_HELPFUL("pried")] apart."

/obj/structure/computerframe/attackby(obj/item/P as obj, mob/user as mob)
	switch(state)
		if(STATE_UNANCHORED)
			if(HAS_TRAIT(P, TRAIT_TOOL_WRENCH))
				playsound(src.loc, 'sound/items/Ratchet.ogg', 25, 1)
				if(do_after(user, 20, INTERRUPT_ALL|BEHAVIOR_IMMOBILE, BUSY_ICON_BUILD))
					to_chat(user, SPAN_NOTICE(" You wrench the frame into place."))
					src.anchored = TRUE
					src.state = STATE_ANCHORED
			if(iswelder(P))
				if(!HAS_TRAIT(P, TRAIT_TOOL_BLOWTORCH))
					to_chat(user, SPAN_WARNING("You need a stronger blowtorch!"))
					return
				var/obj/item/tool/weldingtool/WT = P
				if(!WT.isOn())
					to_chat(user, SPAN_WARNING("\The [WT] needs to be on!"))
					return
				playsound(src.loc, 'sound/items/Welder.ogg', 25, 1)
				if(do_after(user, 20, INTERRUPT_ALL|BEHAVIOR_IMMOBILE, BUSY_ICON_BUILD))
					if(!src || !WT.isOn()) return
					to_chat(user, SPAN_NOTICE(" You deconstruct the frame."))
					deconstruct()
		if(STATE_ANCHORED)
			if(HAS_TRAIT(P, TRAIT_TOOL_WRENCH))
				playsound(src.loc, 'sound/items/Ratchet.ogg', 25, 1)
				if(do_after(user, 20, INTERRUPT_ALL|BEHAVIOR_IMMOBILE, BUSY_ICON_BUILD))
					to_chat(user, SPAN_NOTICE(" You unfasten the frame."))
					src.anchored = FALSE
					src.state = STATE_UNANCHORED
			if(istype(P, /obj/item/circuitboard/computer) && !circuit)
				if(user.drop_held_item())
					playsound(src.loc, 'sound/items/Deconstruct.ogg', 25, 1)
					to_chat(user, SPAN_NOTICE(" You place the circuit board inside the frame."))
					icon_state = "1"
					circuit = P
					P.forceMove(src)

			if(HAS_TRAIT(P, TRAIT_TOOL_SCREWDRIVER) && circuit)
				playsound(src.loc, 'sound/items/Screwdriver.ogg', 25, 1)
				to_chat(user, SPAN_NOTICE(" You screw the circuit board into place."))
				src.state = STATE_SCREWED_CIRCUIT
				src.icon_state = "2"
			if(HAS_TRAIT(P, TRAIT_TOOL_CROWBAR) && circuit)
				playsound(src.loc, 'sound/items/Crowbar.ogg', 25, 1)
				to_chat(user, SPAN_NOTICE(" You remove the circuit board."))
				src.state = STATE_ANCHORED
				src.icon_state = "0"
				circuit.forceMove(loc)
				src.circuit = null
		if(STATE_SCREWED_CIRCUIT)
			if(HAS_TRAIT(P, TRAIT_TOOL_SCREWDRIVER) && circuit)
				playsound(src.loc, 'sound/items/Screwdriver.ogg', 25, 1)
				to_chat(user, SPAN_NOTICE(" You unfasten the circuit board."))
				src.state = STATE_ANCHORED
				src.icon_state = "1"
			if(istype(P, /obj/item/stack/cable_coil))
				var/obj/item/stack/cable_coil/C = P
				if (C.get_amount() < 5)
					to_chat(user, SPAN_WARNING("You need five coils of wire to add them to the frame."))
					return
				to_chat(user, SPAN_NOTICE("You start to add cables to the frame."))
				playsound(src.loc, 'sound/items/Deconstruct.ogg', 25, 1)
				if(do_after(user, 20, INTERRUPT_ALL|BEHAVIOR_IMMOBILE, BUSY_ICON_BUILD) && state == 2)
					if (C.use(5))
						to_chat(user, SPAN_NOTICE("You add cables to the frame."))
						state = STATE_WIRED
						icon_state = "3"
		if(STATE_WIRED)
			if(HAS_TRAIT(P, TRAIT_TOOL_WIRECUTTERS))
				playsound(src.loc, 'sound/items/Wirecutter.ogg', 25, 1)
				to_chat(user, SPAN_NOTICE(" You remove the cables."))
				src.state = STATE_SCREWED_CIRCUIT
				src.icon_state = "2"
				var/obj/item/stack/cable_coil/A = new /obj/item/stack/cable_coil( src.loc )
				A.amount = 5

			if(istype(P, /obj/item/stack/sheet/glass))
				var/obj/item/stack/sheet/glass/G = P
				if (G.get_amount() < 2)
					to_chat(user, SPAN_WARNING("You need two sheets of glass to put in the glass panel."))
					return
				playsound(src.loc, 'sound/items/Deconstruct.ogg', 25, 1)
				to_chat(user, SPAN_NOTICE("You start to put in the glass panel."))
				if(do_after(user, 20, INTERRUPT_ALL|BEHAVIOR_IMMOBILE, BUSY_ICON_BUILD) && state == 3)
					if (G.use(2))
						to_chat(user, SPAN_NOTICE("You put in the glass panel."))
						src.state = STATE_DISPLAY_IN
						src.icon_state = "4"
		if(STATE_DISPLAY_IN)
			if(HAS_TRAIT(P, TRAIT_TOOL_CROWBAR))
				playsound(src.loc, 'sound/items/Crowbar.ogg', 25, 1)
				to_chat(user, SPAN_NOTICE(" You remove the glass panel."))
				src.state = STATE_WIRED
				src.icon_state = "3"
				new /obj/item/stack/sheet/glass( src.loc, 2 )
			if(HAS_TRAIT(P, TRAIT_TOOL_SCREWDRIVER))
				playsound(src.loc, 'sound/items/Screwdriver.ogg', 25, 1)
				to_chat(user, SPAN_NOTICE(" You connect the monitor."))
				var/B = new src.circuit.build_path ( src.loc )
				src.circuit.construct(B)
				qdel(src)

/obj/structure/computerframe/deconstruct(disassembled = TRUE)
	if(disassembled)
		new /obj/item/stack/sheet/metal(src.loc, 5)
	return ..()

#undef STATE_UNANCHORED
#undef STATE_ANCHORED
#undef STATE_SCREWED_CIRCUIT
#undef STATE_WIRED
#undef STATE_DISPLAY_IN
