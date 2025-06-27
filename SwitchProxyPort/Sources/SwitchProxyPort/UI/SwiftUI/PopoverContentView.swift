import SwiftUI
import Foundation
import AppKit

// Port formatting helper
extension Int {
    var portString: String {
        return String(self)
    }
}

// Pointer cursor on hover modifier
struct PointerOnHoverModifier: ViewModifier {
    @State private var isHovering = false
    
    func body(content: Content) -> some View {
        content
            .onHover { hovering in
                isHovering = hovering
                if hovering {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }
    }
}

extension View {
    func pointerOnHover() -> some View {
        self.modifier(PointerOnHoverModifier())
    }
}

// Compatibility modifiers for macOS 12.0+
struct SymbolEffectModifier: ViewModifier {
    let isActive: Bool
    
    func body(content: Content) -> some View {
        if #available(macOS 14.0, *) {
            content.symbolEffect(.variableColor.iterative, isActive: isActive)
        } else {
            content.opacity(isActive ? 1.0 : 0.7)
        }
    }
}

struct ArrowPulseModifier: ViewModifier {
    @State private var isAnimating = false
    
    func body(content: Content) -> some View {
        if #available(macOS 14.0, *) {
            content.symbolEffect(.pulse.byLayer, isActive: true)
        } else {
            content
                .opacity(isAnimating ? 0.5 : 1.0)
                .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isAnimating)
                .onAppear {
                    isAnimating = true
                }
        }
    }
}

struct BounceEffectModifier: ViewModifier {
    let isActive: Bool
    @State private var scale: CGFloat = 1.0
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .onChange(of: isActive) { active in
                if active {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        scale = 1.2
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            scale = 1.0
                        }
                    }
                }
            }
    }
}

struct PopoverContentView: View {
    @ObservedObject var proxyServer: ProxyServer
    @ObservedObject var configManager: ConfigManager
    @Binding var isPopoverShown: Bool
    
    var onPreferencesClick: () -> Void
    var onQuitClick: () -> Void
    
    @State private var hoveredPort: Int? = nil
    @State private var showingAnimation = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header Section
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.title2)
                        .foregroundColor(.blue)
                        .modifier(SymbolEffectModifier(isActive: proxyServer.isRunning))
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("SwitchProxyPort")
                            .font(.headline)
                            .fontWeight(.medium)
                        
                        Text(proxyServer.isRunning ? "Active" : "Inactive")
                            .font(.caption)
                            .foregroundColor(proxyServer.isRunning ? .green : .secondary)
                    }
                    
                    Spacer()
                    
                    // Power Button
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            if proxyServer.isRunning {
                                proxyServer.stop()
                            } else {
                                proxyServer.start(
                                    listenPort: configManager.currentConfig.listenPort,
                                    targetPort: configManager.currentConfig.currentTargetPort
                                )
                            }
                        }
                    }) {
                        Image(systemName: proxyServer.isRunning ? "power.circle.fill" : "power.circle")
                            .font(.title)
                            .foregroundColor(proxyServer.isRunning ? .green : .gray)
                            .scaleEffect(showingAnimation ? 1.2 : 1.0)
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .onHover { hovering in
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showingAnimation = hovering
                        }
                    }
                    .pointerOnHover()
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(NSColor.controlBackgroundColor))
            )
            .padding(.horizontal, 12)
            
            // Divider
            Divider()
                .padding(.vertical, 12)
            
            // Port Configuration Section
            VStack(alignment: .leading, spacing: 12) {
                // Port Information
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Port Configuration")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        Spacer()
                    }
                    
                    HStack(spacing: 12) {
                        // Listen Port Display
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Listen Port")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(":" + configManager.currentConfig.listenPort.portString)
                                .font(.system(.callout, design: .monospaced))
                                .fontWeight(.medium)
                                .foregroundColor(.blue)
                        }
                        
                        Image(systemName: "arrow.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .modifier(ArrowPulseModifier())
                        
                        // Current Target Port Display
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Target Port")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(":" + configManager.currentConfig.currentTargetPort.portString)
                                .font(.system(.callout, design: .monospaced))
                                .fontWeight(.medium)
                                .foregroundColor(proxyServer.isRunning ? .green : .secondary)
                        }
                        
                        Spacer()
                        
                        if proxyServer.isRunning {
                            Text("Active")
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .foregroundColor(.green)
                                )
                        }
                    }
                }
                
                // Target Port Selection
                VStack(alignment: .leading, spacing: 8) {
                    Text("Switch Target Port")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                    ForEach(configManager.currentConfig.targetPorts, id: \.self) { port in
                        PortButtonView(
                            port: port,
                            isSelected: port == configManager.currentConfig.currentTargetPort,
                            isActive: proxyServer.isRunning,
                            isHovered: hoveredPort == port
                        ) {
                            selectPort(port)
                        }
                        .onHover { hovering in
                            hoveredPort = hovering ? port : nil
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            
            // Divider
            Divider()
                .padding(.vertical, 12)
            
            // Action Buttons
            HStack(spacing: 12) {
                Button(action: onPreferencesClick) {
                    HStack(spacing: 6) {
                        Image(systemName: "gear")
                            .font(.caption)
                        Text("Preferences")
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
                .pointerOnHover()
                
                Spacer()
                
                Button(action: onQuitClick) {
                    HStack(spacing: 6) {
                        Image(systemName: "power")
                            .font(.caption)
                        Text("Quit")
                            .font(.caption)
                    }
                    .foregroundColor(.red)
                }
                .buttonStyle(PlainButtonStyle())
                .pointerOnHover()
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
        .padding(.top, 12)
        .frame(width: 280, height: 290)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(NSColor.windowBackgroundColor))
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))  // Ensure clean clipping
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
    
    private func selectPort(_ port: Int) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            configManager.currentConfig.currentTargetPort = port
            configManager.saveConfig()
            
            if proxyServer.isRunning {
                proxyServer.switchTarget(to: port)
            }
        }
    }
}


struct PortButtonView: View {
    let port: Int
    let isSelected: Bool
    let isActive: Bool
    let isHovered: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(port.portString)
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.medium)
                
                if isSelected && isActive {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 4, height: 4)
                        .modifier(BounceEffectModifier(isActive: isSelected))
                }
            }
            .frame(height: 40)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .foregroundColor(backgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(borderColor, lineWidth: isSelected ? 2 : 1)
                    )
            )
            .scaleEffect(isHovered ? 1.05 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isHovered)
        }
        .buttonStyle(PlainButtonStyle())
        .pointerOnHover()
    }
    
    private var backgroundColor: Color {
        if isSelected {
            return isActive ? Color.green.opacity(0.1) : Color.blue.opacity(0.1)
        } else if isHovered {
            return Color(NSColor.controlBackgroundColor)
        } else {
            return Color(NSColor.controlBackgroundColor).opacity(0.5)
        }
    }
    
    private var borderColor: Color {
        if isSelected {
            return isActive ? Color.green : Color.blue
        } else if isHovered {
            return Color(NSColor.controlAccentColor).opacity(0.5)
        } else {
            return Color(NSColor.separatorColor)
        }
    }
}

#Preview {
    PopoverContentView(
        proxyServer: ProxyServer(),
        configManager: ConfigManager.shared,
        isPopoverShown: .constant(true),
        onPreferencesClick: {},
        onQuitClick: {}
    )
}