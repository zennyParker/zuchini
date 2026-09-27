/// Menu configuration consumed by AimSettings. A game must supply the AimingHost adapter.
public enum AimbotMenu {
    public static func definition() throws -> MenuDefinition {
        try MenuDefinition(title: "AIMBOT", sections: [
            MenuSection(id: "aimbot", title: "Aimbot", controls: [
                MenuControl(id: "aimbot.enabled", title: "Aimbot", kind: .toggle(defaultValue: false)),
                MenuControl(id: "aimbot.target", title: "Target", kind: .choice(options: ["Head", "Neck"], defaultValue: "Neck")),
                MenuControl(id: "aimbot.fov", title: "FOV", kind: .slider(range: 1...180, step: 1, defaultValue: 60))
            ])
        ])
    }
}
