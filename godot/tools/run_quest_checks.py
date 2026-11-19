"""Godot v34 task-system acceptance. Historic v33 migration checks belong to V11."""
import run_deepening_checks as gate
gate.UNIT=['quest_guidance_smoke','quest_overhaul_smoke','quest_safety_smoke','quest_input_smoke','quest_production_route','player_rig_smoke','deepening_gait_smoke','wardrobe_art_smoke','five_stage_contact_smoke','five_stage_resident_light_smoke','world_layout_smoke','navigation_smoke','save_atomic_smoke','audio_lifecycle_smoke','audio_window_close_smoke']
gate.GPU=['quest_guidance_render','quest_overhaul_render','player_rig_render','volume_occlusion_render']
if __name__=='__main__':raise SystemExit(gate.main())
