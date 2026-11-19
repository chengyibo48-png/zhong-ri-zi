"""Native v34 fishing gate. Runs isolated saves; never exports game packages."""
import run_deepening_checks as gate
gate.UNIT=['fishing_tension_smoke','fishing_tension_transactions','fishing_tension_content','player_rig_smoke','wardrobe_art_smoke','five_stage_contact_smoke','save_atomic_smoke','audio_lifecycle_smoke']
gate.GPU=['fishing_tension_render','fishing_tension_wardrobe']
if __name__=='__main__':raise SystemExit(gate.main())
