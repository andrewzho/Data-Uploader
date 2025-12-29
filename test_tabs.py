"""Quick test to verify tabs are created"""
import tkinter as tk
from tkinter import ttk

root = tk.Tk()
root.title("Tab Test")
root.geometry("800x600")

notebook = ttk.Notebook(root)
notebook.pack(fill='both', expand=True, padx=10, pady=10)

# Create test tabs
tab1 = ttk.Frame(notebook)
notebook.add(tab1, text="Tab 1")
tk.Label(tab1, text="This is Tab 1").pack(pady=20)

tab2 = ttk.Frame(notebook)
notebook.add(tab2, text="Tab 2")
tk.Label(tab2, text="This is Tab 2").pack(pady=20)

tab3 = ttk.Frame(notebook)
notebook.add(tab3, text="Tab 3")
tk.Label(tab3, text="This is Tab 3").pack(pady=20)

tab4 = ttk.Frame(notebook)
notebook.add(tab4, text="Tab 4")
tk.Label(tab4, text="This is Tab 4").pack(pady=20)

print(f"Total tabs created: {notebook.index('end')}")
print("If you see 4 tabs, the notebook is working correctly")

root.mainloop()

