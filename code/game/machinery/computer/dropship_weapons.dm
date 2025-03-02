/obj/structure/machinery/computer/dropship_weapons
	name = "abstract dropship weapons controls"
	desc = "A computer to manage equipment, weapons and simulations installed on the dropship."
	density = TRUE
	icon = 'icons/obj/structures/machinery/shuttle-parts.dmi'
	icon_state = "consoleright"
	var/faction = FACTION_MARINE
	circuit = null
	unslashable = TRUE
	unacidable = TRUE
	exproof = TRUE
	var/shuttle_tag  // Used to know which shuttle we're linked to.
	var/obj/structure/dropship_equipment/selected_equipment //the currently selected equipment installed on the shuttle this console controls.
	var/list/shuttle_equipments = list() //list of the equipments on the shuttle this console controls
	var/cavebreaker = FALSE //ignore caves and other restrictions?
	var/datum/cas_fire_envelope/firemission_envelope
	var/datum/cas_fire_mission/selected_firemission
	var/datum/cas_fire_mission/editing_firemission
	var/firemission_signal //id of the signal
	var/in_firemission_mode = FALSE
	var/upgraded = MATRIX_DEFAULT // we transport upgrade var from matrixdm
	var/matrixcol //color of matrix, only used when we upgrade to nv
	var/power //level of the property
	var/datum/cas_signal/selected_cas_signal
	var/datum/simulator/simulation
	var/datum/cas_fire_mission/configuration

/obj/structure/machinery/computer/dropship_weapons/Initialize()
	. = ..()
	simulation = new()

/obj/structure/machinery/computer/dropship_weapons/New()
	..()
	if(firemission_envelope)
		firemission_envelope.linked_console = src

/obj/structure/machinery/computer/dropship_weapons/attack_hand(mob/user)
	if(..())
		return
	if(!allowed(user))

		// everyone can access the simulator, requested feature.
		to_chat(user, SPAN_WARNING("Weapons modification access denied, attempting to launch simulation."))

		if(!selected_firemission)
			to_chat(usr, SPAN_WARNING("Firemission must be selected before attempting to run the simulation"))
			return

		tgui_interact(user)
		return 1

	user.set_interaction(src)
	ui_interact(user)

/obj/structure/machinery/computer/dropship_weapons/attackby(obj/item/W, mob/user as mob)
	if(istype(W, /obj/item/frame/matrix_frame))
		var/obj/item/frame/matrix_frame/MATRIX = W
		if(MATRIX.state == ASSEMBLY_LOCKED)
			user.drop_held_item(W, src)
			W.forceMove(src)
			to_chat(user, SPAN_NOTICE("You swap the matrix in the dropship guidance camera system, destroying the older part in the process"))
			upgraded = MATRIX.upgrade
			matrixcol = MATRIX.matrixcol
			power = MATRIX.power

		else
			to_chat(user, SPAN_WARNING("Matrix is not complete!"))

/obj/structure/machinery/computer/dropship_weapons/ui_interact(mob/user, ui_key = "main", datum/nanoui/ui = null, force_open = 0)
	var/data[0]
	var/obj/docking_port/mobile/marine_dropship/dropship = SSshuttle.getShuttle(shuttle_tag)
	if (!istype(dropship))
		return

	var/shuttle_state
	switch(dropship.mode)
		if(SHUTTLE_IDLE)
			shuttle_state = "idle"
		if(SHUTTLE_IGNITING)
			shuttle_state = "warmup"
		if(SHUTTLE_CALL)
			shuttle_state = "in_transit"
		if(SHUTTLE_CRASHED)
			shuttle_state = "crashed"


	var/list/equipment_data = list()
	var/list/targets_data = list()
	var/list/firemission_data = list()
	var/list/firemission_edit_data = list()
	var/list/firemission_edit_timeslices = list()

	for(var/ts = 1; ts<=firemission_envelope.fire_length; ts++)
		firemission_edit_timeslices += ts

	var/current_mission_error = null
	if(!faction)
		return //no faction, no weapons

	var/datum/cas_iff_group/cas_group = GLOB.cas_groups[faction]

	if(!cas_group)
		return //broken group. No fighting

	for(var/X in cas_group.cas_signals)
		var/datum/cas_signal/LT = X
		if(!istype(LT) || !LT.valid_signal())
			continue
		var/area/laser_area = get_area(LT.signal_loc)
		targets_data += list(list("target_name" = "[LT.name] ([laser_area.name])", "target_tag" = LT.target_id))
	shuttle_equipments = dropship.equipments
	var/element_nbr = 1
	for(var/X in dropship.equipments)
		var/obj/structure/dropship_equipment/E = X
		equipment_data += list(list("name"= sanitize(copytext(E.name,1,MAX_MESSAGE_LEN)), "eqp_tag" = element_nbr, "is_weapon" = E.is_weapon, "is_interactable" = E.is_interactable))
		element_nbr++
		E.linked_console = src


	var/selected_eqp_name = ""
	var/selected_eqp_ammo_name = ""
	var/selected_eqp_ammo_amt = 0
	var/selected_eqp_max_ammo_amt = 0
	var/screen_mode = 0
	var/fm_length = 0
	var/fm_offset = 0
	var/fm_direction = ""
	var/fm_step_text = ""
	var/firemission_signal
	var/firemission_stat = 0
	if(selected_equipment)
		selected_eqp_name = sanitize(copytext(selected_equipment.name,1,MAX_MESSAGE_LEN))
		if(selected_equipment.ammo_equipped)
			selected_eqp_ammo_name = sanitize(copytext(selected_equipment.ammo_equipped.name,1,MAX_MESSAGE_LEN))
			selected_eqp_ammo_amt = selected_equipment.ammo_equipped.ammo_count
			selected_eqp_max_ammo_amt = selected_equipment.ammo_equipped.max_ammo_count
		screen_mode = selected_equipment.screen_mode

	var/firemission_id = 1
	var/found_selected = FALSE
	if(firemission_envelope)
		firemission_stat = firemission_envelope.stat
		fm_step_text = firemission_envelope.firemission_status_message()
		for(var/datum/cas_fire_mission/X in firemission_envelope.missions)
			if(!istype(X))
				continue //the fuck
			var/error_code = X.check(src)

			var/selected = X == selected_firemission
			if(error_code != FIRE_MISSION_ALL_GOOD && selected)
				selected = FALSE
				selected_firemission = null
			var/can_edit = error_code != FIRE_MISSION_CODE_ERROR && !selected

			if(selected)
				found_selected = TRUE
			var/can_interact = firemission_envelope.stat == FIRE_MISSION_STATE_IDLE && error_code == FIRE_MISSION_ALL_GOOD
			firemission_data += list(list("name"= sanitize(copytext(X.name,1,MAX_MESSAGE_LEN)), "mission_tag" = firemission_id, "can_edit" = can_edit, "can_interact" = can_interact, "selected" = selected))
			firemission_id++

		if(!istype(editing_firemission))
			editing_firemission = null
			//the fuck

		if(editing_firemission)
			var/error_code = editing_firemission.check(src)
			var/can_edit = error_code != FIRE_MISSION_CODE_ERROR
			if(error_code != FIRE_MISSION_ALL_GOOD)
				current_mission_error = editing_firemission.error_message(error_code)
			else
				current_mission_error = null
			if(!can_edit)
				editing_firemission = null
				//abort
			else
				screen_mode = 2
				for(var/datum/cas_fire_mission_record/firerec in editing_firemission.records)
					var/gimbal = firerec.get_offsets()
					var/ammo = firerec.get_ammo()
					var/offsets = new /list(firerec.offsets.len)
					for(var/idx = 1; idx < firerec.offsets.len; idx++)
						offsets[idx] = firerec.offsets[idx] == null ? "-" : firerec.offsets[idx]
					firemission_edit_data += list(list("name" = sanitize(copytext(firerec.weapon.name, 1, 50)), "ammo" = ammo, "gimbal" = gimbal, "offsets" = firerec.offsets))

		if(!found_selected)
			selected_firemission = null

		if(editing_firemission)
			fm_length = editing_firemission.mission_length

		if((screen_mode != 0 && in_firemission_mode) || !selected_firemission)
			in_firemission_mode = FALSE
		if(selected_firemission && in_firemission_mode)
			if(selected_firemission.check(src)!=FIRE_MISSION_ALL_GOOD)
				in_firemission_mode = FALSE
				selected_firemission = null
		if(selected_firemission && in_firemission_mode)
			screen_mode = 3
			fm_offset = firemission_envelope.recorded_offset
			fm_direction = dir2text(firemission_envelope.recorded_dir)
			if(firemission_envelope.recorded_loc && (!firemission_envelope.recorded_loc.signal_loc || !firemission_envelope.recorded_loc.signal_loc:loc))
				firemission_envelope.recorded_loc = null

			firemission_signal = firemission_envelope.recorded_loc?firemission_envelope.recorded_loc.get_name() : "NOT SELECTED"
			if(!fm_direction)
				fm_direction = "NOT SELECTED"

		if(screen_mode != 3 || !selected_firemission || shuttle_state != "in_transit")
			update_location(null)
	// /if(firemission_envelope)

	data = list(
		"shuttle_state" = shuttle_state,
		"fire_mission_enabled" = dropship.in_flyby,
		"equipment_data" = equipment_data,
		"targets_data" = targets_data,
		"selected_eqp" = selected_eqp_name,
		"selected_eqp_ammo_name" = selected_eqp_ammo_name,
		"selected_eqp_ammo_amt" = selected_eqp_ammo_amt,
		"selected_eqp_max_ammo_amt" = selected_eqp_max_ammo_amt,
		"screen_mode" = screen_mode,
		"firemission_data" = firemission_data,
		"editing_firemission" = editing_firemission,
		"editing_firemission_length" = fm_length,
		"firemission_edit_data" = firemission_edit_data,
		"current_mission_error" = current_mission_error,
		"firemission_edit_timeslices" = firemission_edit_timeslices,
		"has_firemission" = !!firemission_envelope,
		"can_firemission" = !!selected_firemission && shuttle_state == "in_transit",
		"can_launch_firemission" = !!selected_firemission && shuttle_state == "in_transit" && firemission_stat != FIRE_MISSION_STATE_IDLE,
		//firemission related stuff
		"firemission_name" = (selected_firemission ? selected_firemission.name : ""),
		"firemission_selected_laser" = firemission_signal,
		"firemission_offset" = fm_offset,
		"firemission_direction" = fm_direction,
		"firemission_message" = fm_step_text,
		"firemission_step" = firemission_stat,
	)

	ui = SSnano.nanomanager.try_update_ui(user, src, ui_key, ui, data, force_open)

	if (!ui)
		ui = new(user, src, ui_key, "dropship_weapons_console.tmpl", "Weapons Control", 800, 600)
		ui.set_initial_data(data)
		ui.open()
		ui.set_auto_update(1)

/obj/structure/machinery/computer/dropship_weapons/Topic(href, href_list)
	if(..())
		return

	add_fingerprint(usr)

	var/obj/docking_port/mobile/marine_dropship/dropship = SSshuttle.getShuttle(shuttle_tag)
	if (!istype(dropship))
		return

	if(href_list["equip_interact"])
		var/base_tag = text2num(href_list["equip_interact"])
		var/obj/structure/dropship_equipment/E = shuttle_equipments[base_tag]
		E.linked_console = src
		E.equipment_interact(usr)

	if(href_list["open_fire"])
		var/targ_id = text2num(href_list["open_fire"])
		var/mob/M = usr
		if(ishuman(M))
			var/mob/living/carbon/human/H = M
			if(!H.allow_gun_usage)
				to_chat(H, SPAN_WARNING("Your programming prevents you from operating dropship weaponry!"))
				return
		var/obj/structure/dropship_equipment/weapon/DEW = selected_equipment
		if(!selected_equipment || !selected_equipment.is_weapon)
			to_chat(usr, SPAN_WARNING("No weapon selected."))
			return
		if(!skillcheck(M, SKILL_PILOT, DEW.skill_required)) //only pilots can fire dropship weapons.
			to_chat(usr, SPAN_WARNING("You don't have the training to fire this weapon!"))
			return

		if(!faction)
			return //no faction, no weapons

		var/datum/cas_iff_group/cas_group = GLOB.cas_groups[faction]

		if(!cas_group)
			return //broken group. No fighting

		for(var/X in cas_group.cas_signals)
			var/datum/cas_signal/LT = X
			if(LT.target_id == targ_id && LT.valid_signal())
				if(dropship.mode != SHUTTLE_CALL)
					to_chat(usr, SPAN_WARNING("Dropship can only fire while in flight."))
					return
				if(dropship.door_override)
					return
				if(!selected_equipment || !selected_equipment.is_weapon)
					to_chat(usr, SPAN_WARNING("No weapon selected."))
					return
				DEW = selected_equipment // for if the weapon somehow changes
				if(!skillcheck(M, SKILL_PILOT, DEW.skill_required)) //only pilots can fire dropship weapons.
					to_chat(usr, SPAN_WARNING("You don't have the training to fire this weapon!"))
					return
				if(!dropship.in_flyby && DEW.fire_mission_only)
					to_chat(usr, SPAN_WARNING("[DEW] requires a fire mission flight type to be fired."))
					return

				if(!DEW.ammo_equipped || DEW.ammo_equipped.ammo_count <= 0)
					to_chat(usr, SPAN_WARNING("[DEW] has no ammo."))
					return
				if(DEW.last_fired > world.time - DEW.firing_delay)
					to_chat(usr, SPAN_WARNING("[DEW] just fired, wait for it to cool down."))
					return
				if(!LT.signal_loc)
					return
				var/turf/TU = get_turf(LT.signal_loc)
				var/area/targ_area = get_area(LT.signal_loc)
				var/is_outside = FALSE
				if(is_ground_level(TU.z))
					switch(targ_area.ceiling)
						if(CEILING_NONE)
							is_outside = TRUE
						if(CEILING_GLASS)
							is_outside = TRUE
				if(!is_outside && !cavebreaker) //cavebreaker doesn't care
					to_chat(usr, SPAN_WARNING("INVALID TARGET: target must be visible from high altitude."))
					return
				if (protected_by_pylon(TURF_PROTECTION_CAS, TU))
					to_chat(usr, SPAN_WARNING("INVALID TARGET: biological-pattern interference with signal."))
					return
				if(!DEW.ammo_equipped.can_fire_at(TU, usr))
					return

				DEW.open_fire(LT.signal_loc)
				break

	if(href_list["deselect"])
		var/mob/M = usr
		if(!skillcheck(M, SKILL_PILOT, SKILL_PILOT_TRAINED)) //only pilots can fire dropship weapons.
			to_chat(usr, SPAN_WARNING("A screen with graphics and walls of physics and engineering values open, you immediately force it closed."))
			return
		selected_equipment = null

	if(href_list["create_mission"])
		var/mob/M = usr
		if(!skillcheck(M, SKILL_PILOT, SKILL_PILOT_TRAINED)) //only pilots can fire dropship weapons.
			to_chat(usr, SPAN_WARNING("A screen with graphics and walls of physics and engineering values open, you immediately force it closed."))
			return
		if(firemission_envelope.max_mission_len <= firemission_envelope.missions.len)
			to_chat(usr, SPAN_WARNING("Cannot store more than [firemission_envelope.max_mission_len] Fire Missions."))
			return
		var/fm_name = stripped_input(usr, "", "Enter Fire Mission Name", "Fire Mission [firemission_envelope.missions.len+1]", 50)
		if(!fm_name || length(fm_name) < 5)
			to_chat(usr, SPAN_WARNING("Name too short (at least 5 symbols)."))
			return
		var/fm_length = stripped_input(usr, "Enter length of the Fire Mission. Has to be less than [firemission_envelope.fire_length]. Use something that divides [firemission_envelope.fire_length] for optimal performance.", "Fire Mission Length (in tiles)", "[firemission_envelope.fire_length]", 5)
		var/fm_length_n = text2num(fm_length)
		if(!fm_length_n)
			to_chat(usr, SPAN_WARNING("Incorrect input format."))
			return
		if(fm_length_n > firemission_envelope.fire_length)
			to_chat(usr, SPAN_WARNING("Fire Mission is longer than allowed by this vehicle."))
			return
		if(firemission_envelope.stat != FIRE_MISSION_STATE_IDLE)
			to_chat(usr, SPAN_WARNING("Vehicle has to be idle to allow Fire Mission editing and creation."))
			return
		//everything seems to be fine now
		firemission_envelope.generate_mission(fm_name, fm_length_n)

	if(href_list["mission_tag_delete"])
		var/ref = text2num(href_list["mission_tag_delete"])
		var/mob/M = usr
		if(!skillcheck(M, SKILL_PILOT, SKILL_PILOT_TRAINED)) //only pilots can fire dropship weapons.
			to_chat(usr, SPAN_WARNING("A screen with graphics and walls of physics and engineering values open, you immediately force it closed."))
			return
		if(ref>firemission_envelope.missions.len)
			to_chat(usr, SPAN_WARNING("Fire Mission ID corrupted or already deleted."))
			return
		if(selected_firemission == firemission_envelope.missions[ref])
			to_chat(usr, SPAN_WARNING("Can't delete selected Fire Mission."))
			return
		var/result = firemission_envelope.delete_firemission(ref)
		if(result != 1)
			to_chat(usr, SPAN_WARNING("Unable to delete Fire Mission while in combat."))
			return

	if(href_list["mission_tag"])
		var/ref = text2num(href_list["mission_tag"])
		var/mob/M = usr
		if(!skillcheck(M, SKILL_PILOT, SKILL_PILOT_TRAINED)) //only pilots can fire dropship weapons.
			to_chat(usr, SPAN_WARNING("A screen with graphics and walls of physics and engineering values open, you immediately force it closed."))
			return
		if(ref>firemission_envelope.missions.len)
			to_chat(usr, SPAN_WARNING("Fire Mission ID corrupted or deleted."))
			return
		if(firemission_envelope.stat > FIRE_MISSION_STATE_IN_TRANSIT && firemission_envelope.stat < FIRE_MISSION_STATE_COOLDOWN)
			to_chat(usr, SPAN_WARNING("Fire Mission already underway."))
			return
		if(selected_firemission == firemission_envelope.missions[ref])
			selected_firemission = null
		else
			selected_firemission = firemission_envelope.missions[ref]

	if(href_list["mission_tag_edit"])
		var/ref = text2num(href_list["mission_tag_edit"])
		var/mob/M = usr
		if(!skillcheck(M, SKILL_PILOT, SKILL_PILOT_TRAINED)) //only pilots can fire dropship weapons.
			to_chat(usr, SPAN_WARNING("A screen with graphics and walls of physics and engineering values open, you immediately force it closed."))
			return
		if(ref>firemission_envelope.missions.len)
			to_chat(usr, SPAN_WARNING("Fire Mission ID corrupted or deleted."))
			return
		if(selected_firemission == firemission_envelope.missions[ref])
			to_chat(usr, SPAN_WARNING("Can't edit selected Fire Mission."))
			return
		if(firemission_envelope.stat > FIRE_MISSION_STATE_IN_TRANSIT && firemission_envelope.stat < FIRE_MISSION_STATE_COOLDOWN)
			to_chat(usr, SPAN_WARNING("Fire Mission already underway."))
			return
		editing_firemission = firemission_envelope.missions[ref]

	if(href_list["leave_firemission_editing"])
		editing_firemission = null

	if(href_list["switch_to_firemission"])
		var/mob/M = usr
		if(!skillcheck(M, SKILL_PILOT, SKILL_PILOT_TRAINED)) //only pilots can fire dropship weapons.
			to_chat(usr, SPAN_WARNING("A screen with graphics and walls of physics and engineering values open, you immediately force it closed."))
			return
		in_firemission_mode = TRUE

	if(href_list["switch_to_simulation"])
		if(!selected_firemission)
			to_chat(usr, SPAN_WARNING("Select a firemission before attempting to run the simulation"))
			return

		configuration = selected_firemission

		// simulation mode
		tgui_interact(usr)

	if(href_list["leave_firemission_execution"])
		var/mob/M = usr
		if(!skillcheck(M, SKILL_PILOT, SKILL_PILOT_TRAINED)) //only pilots can fire dropship weapons.
			to_chat(usr, SPAN_WARNING("A screen with graphics and walls of physics and engineering values open, you immediately force it closed."))
			return
		firemission_envelope.remove_user_from_tracking(usr)
		in_firemission_mode = FALSE

	if(href_list["change_direction"])
		var/mob/M = usr
		if(!skillcheck(M, SKILL_PILOT, SKILL_PILOT_TRAINED)) //only pilots can fire dropship weapons.
			to_chat(usr, SPAN_WARNING("A screen with graphics and walls of physics and engineering values open, you immediately force it closed."))
			return
		var/list/directions = list(dir2text(NORTH), dir2text(SOUTH), dir2text(EAST), dir2text(WEST))
		var/chosen = tgui_input_list(usr, "Select new Direction for the strafing run", "Select Direction", directions)

		var/chosen_dir = text2dir(chosen)
		if(!chosen_dir)
			to_chat(usr, SPAN_WARNING("Error with direction detected."))
			return

		update_direction(chosen_dir)

	if(href_list["change_offset"])
		var/mob/M = usr
		if(!skillcheck(M, SKILL_PILOT, SKILL_PILOT_TRAINED)) //only pilots can fire dropship weapons.
			to_chat(usr, SPAN_WARNING("A screen with graphics and walls of physics and engineering values open, you immediately force it closed."))
			return

		var/chosen = stripped_input(usr, "Select Fire Mission length, from 0 to [firemission_envelope.max_offset]", "Select Offset", "[firemission_envelope.recorded_offset]", 2)
		var/chosen_offset = text2num(chosen)

		if(chosen_offset == null)
			to_chat(usr, SPAN_WARNING("Error with offset detected."))
			return

		update_offset(chosen_offset)

	if(href_list["select_laser_firemission"])
		var/mob/M = usr
		var/targ_id = text2num(href_list["select_laser_firemission"])
		if(!targ_id)
			to_chat(usr, SPAN_WARNING("Bad Target."))
			return
		if(!skillcheck(M, SKILL_PILOT, SKILL_PILOT_TRAINED)) //only pilots can fire dropship weapons.
			to_chat(usr, SPAN_WARNING("A screen with graphics and walls of physics and engineering values open, you immediately force it closed."))
			return
		if(firemission_envelope.stat > FIRE_MISSION_STATE_IN_TRANSIT && firemission_envelope.stat < FIRE_MISSION_STATE_COOLDOWN)
			to_chat(usr, SPAN_WARNING("Fire Mission already underway."))
			return
		if(dropship.mode != SHUTTLE_CALL)
			to_chat(usr, SPAN_WARNING("Shuttle has to be in orbit."))
			return
		var/datum/cas_iff_group/cas_group = GLOB.cas_groups[faction]
		var/datum/cas_signal/cas_sig
		for(var/X in cas_group.cas_signals)
			var/datum/cas_signal/LT = X
			if(LT.target_id == targ_id  && LT.valid_signal())
				cas_sig = LT
		if(!cas_sig)
			to_chat(usr, SPAN_WARNING("Target lost or obstructed."))
			return

		update_location(cas_sig)

	if(href_list["execute_firemission"])
		var/mob/M = usr
		if(ishuman(M))
			var/mob/living/carbon/human/H = M
			if(!H.allow_gun_usage)
				to_chat(H, SPAN_WARNING("Your programming prevents you from operating dropship weaponry!"))
				return
		if(!skillcheck(M, SKILL_PILOT, SKILL_PILOT_TRAINED)) //only pilots can fire dropship weapons.
			to_chat(usr, SPAN_WARNING("A screen with graphics and walls of physics and engineering values open, you immediately force it closed."))
			return
		if(firemission_envelope.stat != FIRE_MISSION_STATE_IDLE)
			to_chat(usr, SPAN_WARNING("Fire Mission already underway."))
			return
		if(dropship.mode != SHUTTLE_CALL)
			to_chat(usr, SPAN_WARNING("Shuttle has to be in orbit."))
			return
		if(!firemission_envelope.recorded_loc)
			to_chat(usr, SPAN_WARNING("Target is not selected or lost."))
			return

		initiate_firemission()

	if(href_list["fm_weapon_id"])
		var/weap_ref = text2num(href_list["fm_weapon_id"])+1
		var/offset_ref = text2num(href_list["fm_offset_id"])+1
		var/mob/M = usr
		if(!skillcheck(M, SKILL_PILOT, SKILL_PILOT_TRAINED)) //only pilots can fire dropship weapons.
			to_chat(usr, SPAN_WARNING("A screen with graphics and walls of physics and engineering values open, you immediately force it closed."))
			return
		if(!editing_firemission)
			to_chat(usr, SPAN_WARNING("You are no longer editing Fire Mission."))
			return
		if(!editing_firemission.records || editing_firemission.records.len<weap_ref)
			to_chat(usr, SPAN_WARNING("Weapon not found."))
			return
		var/datum/cas_fire_mission_record/record = editing_firemission.records[weap_ref]
		if(record.offsets.len < offset_ref)
			to_chat(usr, SPAN_WARNING("Issues with offsets. You have to re-create this mission."))
			return
		if(firemission_envelope.stat > FIRE_MISSION_STATE_IN_TRANSIT && firemission_envelope.stat < FIRE_MISSION_STATE_COOLDOWN)
			to_chat(usr, SPAN_WARNING("Fire Mission already underway."))
			return
		var/list/gimb = record.get_offsets()
		var/min = gimb["min"]
		var/max = gimb["max"]
		var/offset_value = stripped_input(usr, "Enter offset for the [record.weapon.name]. It has to be between [min] and [max]. Enter '-' to remove fire order on this time stamp.", "Firing offset", "[record.offsets[offset_ref]]", 2)
		if(offset_value == null)
			return
		if(offset_value == "-")
			offset_value = "-"
		else
			offset_value = text2num(offset_value)
			if(offset_value == null)
				to_chat(usr, SPAN_WARNING("Incorrect offset value."))
				return
		var/result = firemission_envelope.update_mission(firemission_envelope.missions.Find(editing_firemission), weap_ref, offset_ref, offset_value, TRUE)
		if(result == 0)
			to_chat(usr, SPAN_WARNING("Update caused an error: [firemission_envelope.mission_error]"))
		if(result == -1)
			to_chat(usr, SPAN_WARNING("System Error. Delete this Fire Mission."))

	if(href_list["firemission_camera"])
		if(dropship.mode != SHUTTLE_CALL)
			to_chat(usr, SPAN_WARNING("Shuttle has to be in orbit."))
			return

		if(!firemission_envelope.guidance)
			to_chat(usr, SPAN_WARNING("Guidance is not selected or lost."))
			return

		firemission_envelope.add_user_to_tracking(usr)

		to_chat(usr, "You peek through the guidance camera.")

	if(href_list["cas_camera"])
		if(!ishuman(usr))
			to_chat(usr, SPAN_WARNING("You have no idea how to do that!"))
			return
		if(dropship.mode != SHUTTLE_CALL)
			to_chat(usr, SPAN_WARNING("Shuttle has to be in orbit."))
			return

		if(!faction)
			to_chat(usr, SPAN_DANGER("Bug encountered, this console doesn't have a faction set, report this to a coder!"))
			return

		var/datum/cas_iff_group/cas_group = GLOB.cas_groups[faction]
		if(!cas_group)
			to_chat(usr, SPAN_DANGER("Bug encountered, no CAS group exists for this console, report this to a coder!"))
			return

		var/targ_id = text2num(href_list["cas_camera"])

		var/datum/cas_signal/new_signal
		for(var/datum/cas_signal/LT as anything in cas_group.cas_signals)
			if(LT.target_id == targ_id && LT.valid_signal())
				new_signal = LT
				break

		if(!new_signal)
			to_chat(usr, SPAN_WARNING("Target lost or obstructed."))
			return

		if(usr in selected_cas_signal?.linked_cam?.viewing_users) // Reset previous cam
			remove_from_view(usr)

		selected_cas_signal = new_signal
		if(selected_cas_signal && selected_cas_signal.linked_cam)
			selected_cas_signal.linked_cam.view_directly(usr)
		else
			to_chat(usr, SPAN_WARNING("Error!"))
			return
		give_action(usr, /datum/action/human_action/cancel_view)
		RegisterSignal(usr, COMSIG_MOB_RESET_VIEW, PROC_REF(remove_from_view))
		RegisterSignal(usr, COMSIG_MOB_RESISTED, PROC_REF(remove_from_view))
		firemission_envelope.apply_upgrade(usr)
		to_chat(usr, SPAN_NOTICE("You peek through the guidance camera."))

	ui_interact(usr)

/obj/structure/machinery/computer/dropship_weapons/proc/remove_from_view(mob/living/carbon/human/user)
	UnregisterSignal(user, COMSIG_MOB_RESET_VIEW)
	UnregisterSignal(user, COMSIG_MOB_RESISTED)
	if(selected_cas_signal && selected_cas_signal.linked_cam)
		selected_cas_signal.linked_cam.remove_from_view(user)
	firemission_envelope.remove_upgrades(user)

/obj/structure/machinery/computer/dropship_weapons/proc/initiate_firemission()
	set waitfor = 0
	var/obj/docking_port/mobile/marine_dropship/dropship = SSshuttle.getShuttle(shuttle_tag)
	if (!istype(dropship))
		return
	if (dropship.timer && dropship.timeLeft(1) < firemission_envelope.get_total_duration())
		to_chat(usr, "Not enough time to complete the Fire Mission")
		return
	if (!dropship.in_flyby || dropship.mode != SHUTTLE_CALL)
		to_chat(usr, "Has to be in Fly By mode")
		return

	var/fmid = firemission_envelope.missions.Find(selected_firemission)
	if(!fmid)
		to_chat(usr, "No Firemission selected")
		return

	var/result = firemission_envelope.execute_firemission(firemission_envelope.recorded_loc, firemission_envelope.recorded_offset, firemission_envelope.recorded_dir, fmid)
	if(result<1)
		to_chat(usr, "Screen beeps with an error: "+ firemission_envelope.mission_error)
	else
		update_trace_loc()

/obj/structure/machinery/computer/dropship_weapons/proc/update_offset(new_offset)
	var/result = firemission_envelope.change_offset(new_offset)
	if(result<1)
		to_chat(usr, "Screen beeps with an error: "+ firemission_envelope.mission_error)
	else
		update_trace_loc()

/obj/structure/machinery/computer/dropship_weapons/proc/update_location(new_location)
	var/result = firemission_envelope.change_target_loc(new_location)
	if(result<1)
		to_chat(usr, "Screen beeps with an error: "+ firemission_envelope.mission_error)
	else
		update_trace_loc()


/obj/structure/machinery/computer/dropship_weapons/proc/update_direction(new_direction)
	var/result = firemission_envelope.change_direction(new_direction)
	if(result<1)
		to_chat(usr, "Screen beeps with an error: " + firemission_envelope.mission_error)
	else
		update_trace_loc()

/obj/structure/machinery/computer/dropship_weapons/on_unset_interaction(mob/user)
	..()
	if(firemission_envelope && firemission_envelope.guidance)
		firemission_envelope.remove_user_from_tracking(user)

/obj/structure/machinery/computer/dropship_weapons/proc/update_trace_loc()
	if(!firemission_envelope)
		return
	if(firemission_envelope.recorded_loc == null || firemission_envelope.recorded_dir == null || firemission_envelope.recorded_offset == null)
		return
	if(firemission_envelope.recorded_loc.obstructed_signal())
		if(firemission_envelope.user_is_guided(usr))
			to_chat(usr, SPAN_WARNING("Signal Obstructed. You have to go in blind."))
		return
	var/sx = 0
	var/sy = 0
	switch(firemission_envelope.recorded_dir)
		if(NORTH) //default direction
			sx = 0
			sy = 1
		if(SOUTH)
			sx = 0
			sy = -1
		if(EAST)
			sx = 1
			sy = 0
		if(WEST)
			sx = -1
			sy = 0
	var/turf/tt_turf = get_turf(firemission_envelope.recorded_loc.signal_loc)
	if(!tt_turf)
		return
	var/turf/shootloc = locate(tt_turf.x + sx*firemission_envelope.recorded_offset, tt_turf.y + sy*firemission_envelope.recorded_offset,tt_turf.z)
	if(!shootloc)
		return
	var/area/laser_area = get_area(shootloc)
	if(!istype(laser_area) || CEILING_IS_PROTECTED(laser_area.ceiling, CEILING_PROTECTION_TIER_1))
		if(firemission_envelope.user_is_guided(usr))
			to_chat(usr, SPAN_WARNING("Vision Obstructed. You have to go in blind."))
		firemission_envelope.change_current_loc()
	else
		firemission_envelope.change_current_loc(shootloc)

/obj/structure/machinery/computer/dropship_weapons/dropship1
	name = "\improper 'Alamo' weapons controls"
	req_one_access = list(ACCESS_MARINE_LEADER, ACCESS_MARINE_DROPSHIP, ACCESS_WY_FLIGHT)
	firemission_envelope = new /datum/cas_fire_envelope/uscm_dropship()

/obj/structure/machinery/computer/dropship_weapons/dropship1/New()
	..()
	shuttle_tag = DROPSHIP_ALAMO

/obj/structure/machinery/computer/dropship_weapons/dropship2
	name = "\improper 'Normandy' weapons controls"
	req_one_access = list(ACCESS_MARINE_LEADER, ACCESS_MARINE_DROPSHIP, ACCESS_WY_FLIGHT)
	firemission_envelope = new /datum/cas_fire_envelope/uscm_dropship()

/obj/structure/machinery/computer/dropship_weapons/dropship2/New()
	..()
	shuttle_tag = DROPSHIP_NORMANDY

/obj/structure/machinery/computer/dropship_weapons/Destroy()
	. = ..()

	QDEL_NULL(firemission_envelope)

// CAS TGUI SHIT \\

/obj/structure/machinery/computer/dropship_weapons/tgui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "CasSim", "[src.name]")
		ui.open()

/obj/structure/machinery/computer/dropship_weapons/ui_state(mob/user) // we gotta do custom shit here so that it always closes instead of suspending
	return GLOB.not_incapacitated_and_adjacent_strict_state

/obj/structure/machinery/computer/dropship_weapons/ui_status(mob/user, datum/ui_state/state)
	. = ..()
	if(inoperable())
		return UI_CLOSE

/obj/structure/machinery/computer/dropship_weapons/ui_data(mob/user)
	var/list/data = list()

	data["configuration"] = configuration
	data["looking"] = simulation.looking_at_simulation
	data["dummy_mode"] = simulation.dummy_mode

	data["worldtime"] = world.time
	data["nextdetonationtime"] = simulation.detonation_cooldown
	data["detonation_cooldown"] = simulation.detonation_cooldown_time

	return data

/obj/structure/machinery/computer/dropship_weapons/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return

	var/user = ui.user

	switch(action)
		if("start_watching")
			simulation.start_watching(user)
			. = TRUE

		if("stop_watching")
			simulation.stop_watching(user)
			. = TRUE

		if("execute_simulated_firemission")
			if(!configuration)
				to_chat(user, SPAN_WARNING("No configured firemission"))
				return
			simulate_firemission(user)
			. = TRUE

		if("switch_firemission")
			configuration = tgui_input_list(user, "Select firemission to simulate", "Select firemission", firemission_envelope.missions, 30 SECONDS)
			if(!selected_firemission)
				to_chat(user, SPAN_WARNING("No configured firemission"))
				return
			if(!configuration)
				configuration = selected_firemission
			. = TRUE

		if("switchmode")
			simulation.dummy_mode = tgui_input_list(user, "Select target type to simulate", "Target type", simulation.target_types, 30 SECONDS)
			if(!simulation.dummy_mode)
				simulation.dummy_mode = CLF_MODE
			. = TRUE

/obj/structure/machinery/computer/dropship_weapons/ui_close(mob/user)
	. = ..()
	if(simulation.looking_at_simulation)
		simulation.stop_watching(user)

// CAS TGUI SHIT END \\

/obj/structure/machinery/computer/dropship_weapons/proc/simulate_firemission(mob/living/user)

	if(!configuration)
		to_chat(user, SPAN_WARNING("Configure a firemission before attempting to run the simulation"))
		return
	if(configuration.check(src) != FIRE_MISSION_ALL_GOOD)
		to_chat(user, SPAN_WARNING("Configured firemission has errors, fix the errors before attempting to run the simulation"))
		return

	simulation.spawn_mobs(user)

	if(!simulation.sim_camera)
		to_chat(user, SPAN_WARNING("The simulator has malfunctioned!"))

	//acutal firemission
	configuration.simulate_execute_firemission(src, get_turf(simulation.sim_camera), user)
