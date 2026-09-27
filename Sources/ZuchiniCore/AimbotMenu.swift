/// The UI configuration only. A host must implement gameplay behavior separately.
public enum AimbotMenu {
    public static func definition() throws -> MenuDefinition {
        try MenuDefinition(title: "AIMBOT", sections: [
            MenuSection(id: "aimbot", title: "Aimbot", controls: [
                MenuControl(id: "aimbot.enabled", title: "Aimbot", kind: .toggle(defaultValue: false)),
                MenuControl(id: "aimbot.target", title: "Target", kind: .choice(options: ["Head", "Neck"], defaultValue: "Neck")),
                MenuControl(id: "aimbot.fov", title: "FOV", kind: .slider(range: 1...180, step: 1, defaultValue: 60)),
                MenuControl(id: "aimbot.speed", title: "Speed", kind: .slider(range: 0.05...1, step: 0.05, defaultValue: 1))
            ])
        ])
    }
}
