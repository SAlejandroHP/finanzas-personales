import re

with open("lib/features/transactions/presentation/screens/transaction_list_screen.dart", "r") as f:
    lines = f.readlines()

# Let's fix lines 231-240
# We know Expanded is at 195, NotificationListener at 196
for i in range(230, 240):
    if "]," in lines[i] and "]," in lines[i+1]:
        # found the bad block
        lines[i] = "              ),\n" # close Expanded
        lines[i+1] = "            ],\n" # close children of Column
        lines[i+2] = "          );\n" # close Column
        lines[i+3] = "        },\n" # close data:
        lines[i+4] = "        loading: () => const Center(child: CircularProgressIndicator()),\n"
        lines[i+5] = "        error: (err, stack) => Center(child: Text('Error: $err')),\n"
        lines[i+6] = "      ),\n" # close when
        lines[i+7] = "    ),\n" # close Expanded at 127
        break

with open("lib/features/transactions/presentation/screens/transaction_list_screen.dart", "w") as f:
    f.writelines(lines)
