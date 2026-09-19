with open("lib/features/transactions/presentation/screens/transaction_list_screen.dart", "r") as f:
    lines = f.readlines()

for i in range(238, 245):
    if lines[i].strip() == ");" and lines[i+1].strip() == "}":
        lines[i] = "        ],\n      ),\n    );\n"
        break

with open("lib/features/transactions/presentation/screens/transaction_list_screen.dart", "w") as f:
    f.writelines(lines)
