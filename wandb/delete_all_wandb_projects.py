import wandb

api = wandb.Api()

# Fetch all projects under your account/team
projects = api.projects()

for p in projects:
    full_name = f"{p.entity}/{p.name}"
    print(f"\nProcessing project: {full_name}")
    
    try:
        # Get all runs in the project
        runs = list(api.runs(full_name))
        run_count = len(runs)
        
        if run_count == 0:
            print(f"  No runs found in {full_name}")
        else:
            print(f"  Found {run_count} runs. Deleting...")
            deleted_count = 0
            # Delete all runs in the project
            for run in runs:
                try:
                    run.delete()
                    deleted_count += 1
                    print(f"    ✓ Deleted run: {run.id} ({deleted_count}/{run_count})")
                except Exception as e:
                    print(f"    ✗ Failed to delete run {run.id}: {e}")
            
            print(f"  ✓ Successfully deleted {deleted_count}/{run_count} runs from {full_name}")
            
    except Exception as e:
        print(f"  ✗ Failed to process {full_name}: {e}")

print("\n" + "="*50)
print("Done. Note: Projects themselves cannot be deleted via API.")
print("To fully delete projects, use the W&B web interface:")
print("https://wandb.ai -> Project Settings -> Delete Project")
print("="*50)
