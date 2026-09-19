with open("ios/Runner.xcodeproj/project.pbxproj", "r") as f:
    lines = f.readlines()

for i in [973, 1019, 1062]: # 0-indexed, so 974 is 973
    lines[i] = lines[i].replace("15.0", "18.0")

with open("ios/Runner.xcodeproj/project.pbxproj", "w") as f:
    f.writelines(lines)
