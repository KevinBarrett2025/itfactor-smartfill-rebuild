//
//  USDCoinInspector.swift
//  STSiPhone
//
//  Debug helper to print the full node/geometry/material names in ActorCoin.usdz
//

import Foundation
import SceneKit

public enum USDCoinInspector {
    public static func printHierarchy(usdzNamed name: String = "ActorCoin", ext: String = "usdz") {
        guard let url = Bundle.main.url(forResource: name, withExtension: ext),
              let scene = try? SCNScene(url: url, options: nil) else {
            print("❌ Couldn’t load \(name).\(ext) from bundle")
            return
        }
        print("=== \(name).\(ext) — Scene Graph ===")
        scene.rootNode.enumerateChildNodes { node, _ in
            let nodeName = node.name ?? "(unnamed node)"
            var info = "🔹 Node: \(nodeName)"
            if let geometry = node.geometry {
                let gname = geometry.name ?? "(unnamed geometry)"
                let mats = geometry.materials.map { $0.name ?? "(unnamed)" }.joined(separator: ", ")
                info += " | Geometry: \(gname) | Materials: [\(mats)]"
            }
            print(info)
        }
        print("=== end ===")
    }
}
