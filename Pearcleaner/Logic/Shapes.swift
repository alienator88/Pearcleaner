//
//  Shapes.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 11/11/23.
//

import Foundation
import SwiftUI

// Pear Logo
struct Pear: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.size.width
        let height = rect.size.height
        path.move(to: CGPoint(x: 0.5985*width, y: 0.045*height))
        path.addCurve(to: CGPoint(x: 0.508*width, y: 0.141*height), control1: CGPoint(x: 0.571*width, y: 0.0635*height), control2: CGPoint(x: 0.521*width, y: 0.116*height))
        path.addLine(to: CGPoint(x: 0.4985*width, y: 0.159*height))
        path.addLine(to: CGPoint(x: 0.4725*width, y: 0.1325*height))
        path.addCurve(to: CGPoint(x: 0.318*width, y: 0.0975*height), control1: CGPoint(x: 0.433*width, y: 0.092*height), control2: CGPoint(x: 0.383*width, y: 0.0805*height))
        path.addCurve(to: CGPoint(x: 0.2105*width, y: 0.15*height), control1: CGPoint(x: 0.2875*width, y: 0.1055*height), control2: CGPoint(x: 0.231*width, y: 0.133*height))
        path.addLine(to: CGPoint(x: 0.1985*width, y: 0.16*height))
        path.addLine(to: CGPoint(x: 0.2125*width, y: 0.18*height))
        path.addCurve(to: CGPoint(x: 0.316*width, y: 0.273*height), control1: CGPoint(x: 0.2335*width, y: 0.2105*height), control2: CGPoint(x: 0.287*width, y: 0.2585*height))
        path.addCurve(to: CGPoint(x: 0.371*width, y: 0.289*height), control1: CGPoint(x: 0.331*width, y: 0.2805*height), control2: CGPoint(x: 0.354*width, y: 0.287*height))
        path.addLine(to: CGPoint(x: 0.4*width, y: 0.2915*height))
        path.addLine(to: CGPoint(x: 0.375*width, y: 0.318*height))
        path.addCurve(to: CGPoint(x: 0.3195*width, y: 0.443*height), control1: CGPoint(x: 0.3415*width, y: 0.3535*height), control2: CGPoint(x: 0.326*width, y: 0.388*height))
        path.addCurve(to: CGPoint(x: 0.2635*width, y: 0.564*height), control1: CGPoint(x: 0.3125*width, y: 0.501*height), control2: CGPoint(x: 0.302*width, y: 0.5235*height))
        path.addCurve(to: CGPoint(x: 0.19*width, y: 0.7345*height), control1: CGPoint(x: 0.21*width, y: 0.62*height), control2: CGPoint(x: 0.19*width, y: 0.6665*height))
        path.addCurve(to: CGPoint(x: 0.3235*width, y: 0.949*height), control1: CGPoint(x: 0.19*width, y: 0.8305*height), control2: CGPoint(x: 0.2385*width, y: 0.9085*height))
        path.addCurve(to: CGPoint(x: 0.4125*width, y: 0.9675*height), control1: CGPoint(x: 0.3605*width, y: 0.9665*height), control2: CGPoint(x: 0.365*width, y: 0.9675*height))
        path.addCurve(to: CGPoint(x: 0.4875*width, y: 0.958*height), control1: CGPoint(x: 0.449*width, y: 0.9675*height), control2: CGPoint(x: 0.4695*width, y: 0.965*height))
        path.addCurve(to: CGPoint(x: 0.547*width, y: 0.9595*height), control1: CGPoint(x: 0.5125*width, y: 0.949*height), control2: CGPoint(x: 0.513*width, y: 0.949*height))
        path.addCurve(to: CGPoint(x: 0.759*width, y: 0.9135*height), control1: CGPoint(x: 0.6225*width, y: 0.983*height), control2: CGPoint(x: 0.702*width, y: 0.9655*height))
        path.addCurve(to: CGPoint(x: 0.7975*width, y: 0.817*height), control1: CGPoint(x: 0.8085*width, y: 0.8675*height), control2: CGPoint(x: 0.8225*width, y: 0.8335*height))
        path.addCurve(to: CGPoint(x: 0.7615*width, y: 0.817*height), control1: CGPoint(x: 0.786*width, y: 0.8095*height), control2: CGPoint(x: 0.7835*width, y: 0.8095*height))
        path.addCurve(to: CGPoint(x: 0.661*width, y: 0.8015*height), control1: CGPoint(x: 0.723*width, y: 0.83*height), control2: CGPoint(x: 0.6935*width, y: 0.8255*height))
        path.addCurve(to: CGPoint(x: 0.634*width, y: 0.6745*height), control1: CGPoint(x: 0.6245*width, y: 0.7745*height), control2: CGPoint(x: 0.611*width, y: 0.711*height))
        path.addCurve(to: CGPoint(x: 0.6545*width, y: 0.618*height), control1: CGPoint(x: 0.659*width, y: 0.6345*height), control2: CGPoint(x: 0.6605*width, y: 0.631*height))
        path.addCurve(to: CGPoint(x: 0.6325*width, y: 0.6*height), control1: CGPoint(x: 0.651*width, y: 0.611*height), control2: CGPoint(x: 0.6415*width, y: 0.603*height))
        path.addCurve(to: CGPoint(x: 0.575*width, y: 0.5175*height), control1: CGPoint(x: 0.603*width, y: 0.59*height), control2: CGPoint(x: 0.575*width, y: 0.55*height))
        path.addCurve(to: CGPoint(x: 0.6595*width, y: 0.4255*height), control1: CGPoint(x: 0.575*width, y: 0.4685*height), control2: CGPoint(x: 0.609*width, y: 0.4315*height))
        path.addCurve(to: CGPoint(x: 0.691*width, y: 0.4095*height), control1: CGPoint(x: 0.6755*width, y: 0.4235*height), control2: CGPoint(x: 0.684*width, y: 0.419*height))
        path.addCurve(to: CGPoint(x: 0.691*width, y: 0.3745*height), control1: CGPoint(x: 0.701*width, y: 0.3965*height), control2: CGPoint(x: 0.701*width, y: 0.396*height))
        path.addCurve(to: CGPoint(x: 0.565*width, y: 0.2645*height), control1: CGPoint(x: 0.667*width, y: 0.3215*height), control2: CGPoint(x: 0.6175*width, y: 0.278*height))
        path.addLine(to: CGPoint(x: 0.54*width, y: 0.258*height))
        path.addLine(to: CGPoint(x: 0.54*width, y: 0.2355*height))
        path.addCurve(to: CGPoint(x: 0.6215*width, y: 0.102*height), control1: CGPoint(x: 0.54*width, y: 0.192*height), control2: CGPoint(x: 0.5745*width, y: 0.1355*height))
        path.addCurve(to: CGPoint(x: 0.66*width, y: 0.0575*height), control1: CGPoint(x: 0.653*width, y: 0.0795*height), control2: CGPoint(x: 0.66*width, y: 0.0715*height))
        path.addCurve(to: CGPoint(x: 0.6315*width, y: 0.03*height), control1: CGPoint(x: 0.66*width, y: 0.044*height), control2: CGPoint(x: 0.6455*width, y: 0.03*height))
        path.addCurve(to: CGPoint(x: 0.5985*width, y: 0.045*height), control1: CGPoint(x: 0.626*width, y: 0.03*height), control2: CGPoint(x: 0.6115*width, y: 0.037*height))
        path.closeSubpath()
        path.move(to: CGPoint(x: 0.4155*width, y: 0.1615*height))
        path.addCurve(to: CGPoint(x: 0.444*width, y: 0.19*height), control1: CGPoint(x: 0.4245*width, y: 0.1675*height), control2: CGPoint(x: 0.4375*width, y: 0.1805*height))
        path.addLine(to: CGPoint(x: 0.4555*width, y: 0.2075*height))
        path.addLine(to: CGPoint(x: 0.445*width, y: 0.216*height))
        path.addCurve(to: CGPoint(x: 0.369*width, y: 0.23*height), control1: CGPoint(x: 0.4265*width, y: 0.231*height), control2: CGPoint(x: 0.397*width, y: 0.2365*height))
        path.addCurve(to: CGPoint(x: 0.285*width, y: 0.175*height), control1: CGPoint(x: 0.345*width, y: 0.224*height), control2: CGPoint(x: 0.285*width, y: 0.185*height))
        path.addCurve(to: CGPoint(x: 0.2865*width, y: 0.17*height), control1: CGPoint(x: 0.285*width, y: 0.1725*height), control2: CGPoint(x: 0.2855*width, y: 0.17*height))
        path.addCurve(to: CGPoint(x: 0.315*width, y: 0.16*height), control1: CGPoint(x: 0.287*width, y: 0.17*height), control2: CGPoint(x: 0.3*width, y: 0.1655*height))
        path.addCurve(to: CGPoint(x: 0.4155*width, y: 0.1615*height), control1: CGPoint(x: 0.3535*width, y: 0.1465*height), control2: CGPoint(x: 0.394*width, y: 0.147*height))
        path.closeSubpath()
        path.move(to: CGPoint(x: 0.553*width, y: 0.3225*height))
        path.addCurve(to: CGPoint(x: 0.62*width, y: 0.369*height), control1: CGPoint(x: 0.5755*width, y: 0.329*height), control2: CGPoint(x: 0.62*width, y: 0.3605*height))
        path.addCurve(to: CGPoint(x: 0.599*width, y: 0.382*height), control1: CGPoint(x: 0.62*width, y: 0.371*height), control2: CGPoint(x: 0.6105*width, y: 0.377*height))
        path.addCurve(to: CGPoint(x: 0.5295*width, y: 0.453*height), control1: CGPoint(x: 0.572*width, y: 0.3945*height), control2: CGPoint(x: 0.5445*width, y: 0.4225*height))
        path.addCurve(to: CGPoint(x: 0.5315*width, y: 0.5815*height), control1: CGPoint(x: 0.512*width, y: 0.4895*height), control2: CGPoint(x: 0.5125*width, y: 0.5425*height))
        path.addCurve(to: CGPoint(x: 0.565*width, y: 0.626*height), control1: CGPoint(x: 0.5395*width, y: 0.597*height), control2: CGPoint(x: 0.5545*width, y: 0.6175*height))
        path.addCurve(to: CGPoint(x: 0.576*width, y: 0.6575*height), control1: CGPoint(x: 0.584*width, y: 0.642*height), control2: CGPoint(x: 0.584*width, y: 0.6425*height))
        path.addCurve(to: CGPoint(x: 0.572*width, y: 0.7725*height), control1: CGPoint(x: 0.5645*width, y: 0.68*height), control2: CGPoint(x: 0.562*width, y: 0.744*height))
        path.addCurve(to: CGPoint(x: 0.6785*width, y: 0.8755*height), control1: CGPoint(x: 0.5875*width, y: 0.8195*height), control2: CGPoint(x: 0.632*width, y: 0.862*height))
        path.addCurve(to: CGPoint(x: 0.6665*width, y: 0.902*height), control1: CGPoint(x: 0.7045*width, y: 0.883*height), control2: CGPoint(x: 0.701*width, y: 0.8905*height))
        path.addCurve(to: CGPoint(x: 0.546*width, y: 0.897*height), control1: CGPoint(x: 0.6305*width, y: 0.9145*height), control2: CGPoint(x: 0.585*width, y: 0.9125*height))
        path.addCurve(to: CGPoint(x: 0.498*width, y: 0.89*height), control1: CGPoint(x: 0.517*width, y: 0.885*height), control2: CGPoint(x: 0.5115*width, y: 0.8845*height))
        path.addCurve(to: CGPoint(x: 0.405*width, y: 0.909*height), control1: CGPoint(x: 0.451*width, y: 0.909*height), control2: CGPoint(x: 0.4415*width, y: 0.911*height))
        path.addCurve(to: CGPoint(x: 0.2925*width, y: 0.8535*height), control1: CGPoint(x: 0.3585*width, y: 0.9065*height), control2: CGPoint(x: 0.3245*width, y: 0.8895*height))
        path.addCurve(to: CGPoint(x: 0.2485*width, y: 0.734*height), control1: CGPoint(x: 0.2625*width, y: 0.8205*height), control2: CGPoint(x: 0.2485*width, y: 0.7825*height))
        path.addCurve(to: CGPoint(x: 0.3115*width, y: 0.597*height), control1: CGPoint(x: 0.2485*width, y: 0.6825*height), control2: CGPoint(x: 0.267*width, y: 0.642*height))
        path.addCurve(to: CGPoint(x: 0.375*width, y: 0.465*height), control1: CGPoint(x: 0.3535*width, y: 0.5545*height), control2: CGPoint(x: 0.3695*width, y: 0.5215*height))
        path.addCurve(to: CGPoint(x: 0.385*width, y: 0.4075*height), control1: CGPoint(x: 0.3775*width, y: 0.441*height), control2: CGPoint(x: 0.382*width, y: 0.415*height))
        path.addCurve(to: CGPoint(x: 0.438*width, y: 0.3395*height), control1: CGPoint(x: 0.394*width, y: 0.3835*height), control2: CGPoint(x: 0.4195*width, y: 0.351*height))
        path.addCurve(to: CGPoint(x: 0.553*width, y: 0.3225*height), control1: CGPoint(x: 0.4785*width, y: 0.3145*height), control2: CGPoint(x: 0.5105*width, y: 0.31*height))
        path.closeSubpath()
        return path
    }
}

// Pear text
struct Pearcleaner: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.size.width
        let height = rect.size.height
        path.move(to: CGPoint(x: 1.10767*width, y: -0.23519*height))
        path.addCurve(to: CGPoint(x: 1.10292*width, y: -0.22248*height), control1: CGPoint(x: 1.10519*width, y: -0.23943*height), control2: CGPoint(x: 1.10375*width, y: -0.23519*height))
        path.addCurve(to: CGPoint(x: 1.09362*width, y: -0.14302*height), control1: CGPoint(x: 1.10044*width, y: -0.1854*height), control2: CGPoint(x: 1.09755*width, y: -0.16315*height))
        path.addCurve(to: CGPoint(x: 1.0744*width, y: -0.09005*height), control1: CGPoint(x: 1.08783*width, y: -0.11442*height), control2: CGPoint(x: 1.07977*width, y: -0.09005*height))
        path.addCurve(to: CGPoint(x: 1.09052*width, y: -0.24684*height), control1: CGPoint(x: 1.07977*width, y: -0.10594*height), control2: CGPoint(x: 1.08928*width, y: -0.16103*height))
        path.addCurve(to: CGPoint(x: 1.05869*width, y: -0.43648*height), control1: CGPoint(x: 1.09217*width, y: -0.36126*height), control2: CGPoint(x: 1.0775*width, y: -0.43648*height))
        path.addCurve(to: CGPoint(x: 1.02955*width, y: -0.36868*height), control1: CGPoint(x: 1.04546*width, y: -0.43648*height), control2: CGPoint(x: 1.03513*width, y: -0.39834*height))
        path.addLine(to: CGPoint(x: 1.03058*width, y: -0.40364*height))
        path.addCurve(to: CGPoint(x: 1.02686*width, y: -0.42377*height), control1: CGPoint(x: 1.031*width, y: -0.41529*height), control2: CGPoint(x: 1.02934*width, y: -0.42377*height))
        path.addLine(to: CGPoint(x: 1.01054*width, y: -0.42377*height))
        path.addCurve(to: CGPoint(x: 1.00578*width, y: -0.40258*height), control1: CGPoint(x: 1.00805*width, y: -0.42377*height), control2: CGPoint(x: 1.00619*width, y: -0.41529*height))
        path.addLine(to: CGPoint(x: 0.98532*width, y: 0.26062*height))
        path.addCurve(to: CGPoint(x: 0.98883*width, y: 0.2818*height), control1: CGPoint(x: 0.98491*width, y: 0.27227*height), control2: CGPoint(x: 0.98656*width, y: 0.2818*height))
        path.addLine(to: CGPoint(x: 1.00516*width, y: 0.2818*height))
        path.addCurve(to: CGPoint(x: 1.01012*width, y: 0.25956*height), control1: CGPoint(x: 1.00805*width, y: 0.2818*height), control2: CGPoint(x: 1.00971*width, y: 0.27333*height))
        path.addLine(to: CGPoint(x: 1.02087*width, y: -0.09111*height))
        path.addCurve(to: CGPoint(x: 1.05146*width, y: -0.31888*height), control1: CGPoint(x: 1.02583*width, y: -0.2532*height), control2: CGPoint(x: 1.03926*width, y: -0.31888*height))
        path.addCurve(to: CGPoint(x: 1.06282*width, y: -0.20023*height), control1: CGPoint(x: 1.06262*width, y: -0.31888*height), control2: CGPoint(x: 1.06572*width, y: -0.26379*height))
        path.addCurve(to: CGPoint(x: 1.04298*width, y: -0.09429*height), control1: CGPoint(x: 1.06034*width, y: -0.14302*height), control2: CGPoint(x: 1.05352*width, y: -0.09429*height))
        path.addCurve(to: CGPoint(x: 1.02976*width, y: -0.09111*height), control1: CGPoint(x: 1.03203*width, y: -0.10594*height), control2: CGPoint(x: 1.03058*width, y: -0.1017*height))
        path.addLine(to: CGPoint(x: 1.02562*width, y: -0.04132*height))
        path.addCurve(to: CGPoint(x: 1.03017*width, y: -0.00848*height), control1: CGPoint(x: 1.02438*width, y: -0.02649*height), control2: CGPoint(x: 1.02542*width, y: -0.01801*height))
        path.addCurve(to: CGPoint(x: 1.05538*width, y: 0.01271*height), control1: CGPoint(x: 1.03348*width, y: -0.00106*height), control2: CGPoint(x: 1.04154*width, y: 0.01271*height))
        path.addCurve(to: CGPoint(x: 1.11801*width, y: -0.19917*height), control1: CGPoint(x: 1.08411*width, y: 0.01271*height), control2: CGPoint(x: 1.10891*width, y: -0.05615*height))
        path.addCurve(to: CGPoint(x: 1.11573*width, y: -0.22248*height), control1: CGPoint(x: 1.11883*width, y: -0.21188*height), control2: CGPoint(x: 1.1178*width, y: -0.2193*height))
        path.closeSubpath()
        path.move(to: CGPoint(x: 1.18208*width, y: -0.214*height))
        path.addCurve(to: CGPoint(x: 1.14695*width, y: -0.09641*height), control1: CGPoint(x: 1.17423*width, y: -0.13137*height), control2: CGPoint(x: 1.15956*width, y: -0.09641*height))
        path.addCurve(to: CGPoint(x: 1.12959*width, y: -0.14302*height), control1: CGPoint(x: 1.13806*width, y: -0.09641*height), control2: CGPoint(x: 1.13248*width, y: -0.11442*height))
        path.addCurve(to: CGPoint(x: 1.17712*width, y: -0.28604*height), control1: CGPoint(x: 1.14757*width, y: -0.1409*height), control2: CGPoint(x: 1.17237*width, y: -0.18434*height))
        path.addCurve(to: CGPoint(x: 1.14984*width, y: -0.43648*height), control1: CGPoint(x: 1.18126*width, y: -0.37186*height), control2: CGPoint(x: 1.16844*width, y: -0.43648*height))
        path.addCurve(to: CGPoint(x: 1.10148*width, y: -0.23095*height), control1: CGPoint(x: 1.12918*width, y: -0.43648*height), control2: CGPoint(x: 1.10644*width, y: -0.35702*height))
        path.addCurve(to: CGPoint(x: 1.1424*width, y: 0.01271*height), control1: CGPoint(x: 1.0959*width, y: -0.09323*height), control2: CGPoint(x: 1.11533*width, y: 0.01271*height))
        path.addCurve(to: CGPoint(x: 1.198*width, y: -0.19917*height), control1: CGPoint(x: 1.16824*width, y: 0.01271*height), control2: CGPoint(x: 1.18973*width, y: -0.08263*height))
        path.addCurve(to: CGPoint(x: 1.19573*width, y: -0.22248*height), control1: CGPoint(x: 1.19883*width, y: -0.21082*height), control2: CGPoint(x: 1.19821*width, y: -0.21824*height))
        path.addLine(to: CGPoint(x: 1.18766*width, y: -0.23519*height))
        path.addCurve(to: CGPoint(x: 1.18208*width, y: -0.214*height), control1: CGPoint(x: 1.18518*width, y: -0.23943*height), control2: CGPoint(x: 1.18415*width, y: -0.23519*height))
        path.closeSubpath()
        path.move(to: CGPoint(x: 1.12773*width, y: -0.20659*height))
        path.addCurve(to: CGPoint(x: 1.12794*width, y: -0.214*height), control1: CGPoint(x: 1.12773*width, y: -0.20871*height), control2: CGPoint(x: 1.12794*width, y: -0.21188*height))
        path.addCurve(to: CGPoint(x: 1.14922*width, y: -0.32736*height), control1: CGPoint(x: 1.13021*width, y: -0.27863*height), control2: CGPoint(x: 1.14137*width, y: -0.32736*height))
        path.addCurve(to: CGPoint(x: 1.15563*width, y: -0.2977*height), control1: CGPoint(x: 1.15336*width, y: -0.32736*height), control2: CGPoint(x: 1.15563*width, y: -0.31465*height))
        path.addCurve(to: CGPoint(x: 1.12773*width, y: -0.20659*height), control1: CGPoint(x: 1.15563*width, y: -0.25426*height), control2: CGPoint(x: 1.14178*width, y: -0.20976*height))
        path.closeSubpath()
        path.move(to: CGPoint(x: 1.21075*width, y: 0.01271*height))
        path.addCurve(to: CGPoint(x: 1.24237*width, y: -0.0678*height), control1: CGPoint(x: 1.22604*width, y: 0.01271*height), control2: CGPoint(x: 1.23782*width, y: -0.0339*height))
        path.addCurve(to: CGPoint(x: 1.26552*width, y: 0.01271*height), control1: CGPoint(x: 1.24547*width, y: -0.01907*height), control2: CGPoint(x: 1.25373*width, y: 0.01271*height))
        path.addCurve(to: CGPoint(x: 1.30644*width, y: -0.19917*height), control1: CGPoint(x: 1.28866*width, y: 0.01271*height), control2: CGPoint(x: 1.30189*width, y: -0.11018*height))
        path.addCurve(to: CGPoint(x: 1.30416*width, y: -0.22248*height), control1: CGPoint(x: 1.30706*width, y: -0.21082*height), control2: CGPoint(x: 1.30664*width, y: -0.21824*height))
        path.addLine(to: CGPoint(x: 1.2961*width, y: -0.23519*height))
        path.addCurve(to: CGPoint(x: 1.29135*width, y: -0.22248*height), control1: CGPoint(x: 1.29362*width, y: -0.23943*height), control2: CGPoint(x: 1.29218*width, y: -0.23519*height))
        path.addCurve(to: CGPoint(x: 1.27192*width, y: -0.09429*height), control1: CGPoint(x: 1.28846*width, y: -0.18328*height), control2: CGPoint(x: 1.28143*width, y: -0.09429*height))
        path.addCurve(to: CGPoint(x: 1.26717*width, y: -0.18434*height), control1: CGPoint(x: 1.26614*width, y: -0.09429*height), control2: CGPoint(x: 1.26552*width, y: -0.12819*height))
        path.addLine(to: CGPoint(x: 1.27378*width, y: -0.40258*height))
        path.addCurve(to: CGPoint(x: 1.27027*width, y: -0.42377*height), control1: CGPoint(x: 1.2742*width, y: -0.41423*height), control2: CGPoint(x: 1.27275*width, y: -0.42377*height))
        path.addLine(to: CGPoint(x: 1.25373*width, y: -0.42377*height))
        path.addCurve(to: CGPoint(x: 1.24898*width, y: -0.40258*height), control1: CGPoint(x: 1.25125*width, y: -0.42377*height), control2: CGPoint(x: 1.24939*width, y: -0.41529*height))
        path.addLine(to: CGPoint(x: 1.24877*width, y: -0.39622*height))
        path.addCurve(to: CGPoint(x: 1.22769*width, y: -0.43648*height), control1: CGPoint(x: 1.24547*width, y: -0.41105*height), control2: CGPoint(x: 1.23885*width, y: -0.43648*height))
        path.addCurve(to: CGPoint(x: 1.18264*width, y: -0.24473*height), control1: CGPoint(x: 1.20765*width, y: -0.43648*height), control2: CGPoint(x: 1.18925*width, y: -0.35596*height))
        path.addCurve(to: CGPoint(x: 1.21075*width, y: 0.01271*height), control1: CGPoint(x: 1.1752*width, y: -0.11865*height), control2: CGPoint(x: 1.18512*width, y: 0.01271*height))
        path.closeSubpath()
        path.move(to: CGPoint(x: 1.24567*width, y: -0.29346*height))
        path.addCurve(to: CGPoint(x: 1.21901*width, y: -0.09429*height), control1: CGPoint(x: 1.24278*width, y: -0.18858*height), control2: CGPoint(x: 1.23183*width, y: -0.09429*height))
        path.addCurve(to: CGPoint(x: 1.20806*width, y: -0.21294*height), control1: CGPoint(x: 1.2093*width, y: -0.09429*height), control2: CGPoint(x: 1.20496*width, y: -0.15044*height))
        path.addCurve(to: CGPoint(x: 1.23245*width, y: -0.3263*height), control1: CGPoint(x: 1.21178*width, y: -0.28604*height), control2: CGPoint(x: 1.22232*width, y: -0.3263*height))
        path.addCurve(to: CGPoint(x: 1.24567*width, y: -0.29346*height), control1: CGPoint(x: 1.23968*width, y: -0.3263*height), control2: CGPoint(x: 1.24361*width, y: -0.30511*height))
        path.closeSubpath()
        path.move(to: CGPoint(x: 1.36936*width, y: -0.22248*height))
        path.addCurve(to: CGPoint(x: 1.34807*width, y: -0.09429*height), control1: CGPoint(x: 1.36626*width, y: -0.17904*height), control2: CGPoint(x: 1.35799*width, y: -0.09429*height))
        path.addCurve(to: CGPoint(x: 1.34228*width, y: -0.16527*height), control1: CGPoint(x: 1.34331*width, y: -0.09429*height), control2: CGPoint(x: 1.34001*width, y: -0.11442*height))
        path.addCurve(to: CGPoint(x: 1.34972*width, y: -0.31253*height), control1: CGPoint(x: 1.34497*width, y: -0.22777*height), control2: CGPoint(x: 1.34931*width, y: -0.30405*height))
        path.addCurve(to: CGPoint(x: 1.34393*width, y: -0.38245*height), control1: CGPoint(x: 1.35117*width, y: -0.34749*height), control2: CGPoint(x: 1.35075*width, y: -0.36656*height))
        path.addCurve(to: CGPoint(x: 1.315*width, y: -0.44813*height), control1: CGPoint(x: 1.3336*width, y: -0.40576*height), control2: CGPoint(x: 1.32099*width, y: -0.42589*height))
        path.addCurve(to: CGPoint(x: 1.30322*width, y: -0.52017*height), control1: CGPoint(x: 1.31541*width, y: -0.48945*height), control2: CGPoint(x: 1.31128*width, y: -0.52441*height))
        path.addCurve(to: CGPoint(x: 1.29495*width, y: -0.40258*height), control1: CGPoint(x: 1.29392*width, y: -0.51594*height), control2: CGPoint(x: 1.28999*width, y: -0.46508*height))
        path.addCurve(to: CGPoint(x: 1.29061*width, y: -0.21506*height), control1: CGPoint(x: 1.29619*width, y: -0.3655*height), control2: CGPoint(x: 1.29537*width, y: -0.27969*height))
        path.addCurve(to: CGPoint(x: 1.29206*width, y: -0.19493*height), control1: CGPoint(x: 1.28979*width, y: -0.20553*height), control2: CGPoint(x: 1.2902*width, y: -0.19811*height))
        path.addLine(to: CGPoint(x: 1.30177*width, y: -0.17586*height))
        path.addCurve(to: CGPoint(x: 1.30549*width, y: -0.18434*height), control1: CGPoint(x: 1.30363*width, y: -0.17268*height), control2: CGPoint(x: 1.30487*width, y: -0.17374*height))
        path.addCurve(to: CGPoint(x: 1.31211*width, y: -0.35279*height), control1: CGPoint(x: 1.30859*width, y: -0.23519*height), control2: CGPoint(x: 1.31087*width, y: -0.29346*height))
        path.addLine(to: CGPoint(x: 1.32017*width, y: -0.33372*height))
        path.addCurve(to: CGPoint(x: 1.32347*width, y: -0.29664*height), control1: CGPoint(x: 1.32347*width, y: -0.3263*height), control2: CGPoint(x: 1.32451*width, y: -0.31783*height))
        path.addCurve(to: CGPoint(x: 1.31583*width, y: -0.14408*height), control1: CGPoint(x: 1.32079*width, y: -0.23625*height), control2: CGPoint(x: 1.31748*width, y: -0.19387*height))
        path.addCurve(to: CGPoint(x: 1.3429*width, y: 0.01271*height), control1: CGPoint(x: 1.31335*width, y: -0.06145*height), control2: CGPoint(x: 1.32554*width, y: 0.01271*height))
        path.addCurve(to: CGPoint(x: 1.38444*width, y: -0.19917*height), control1: CGPoint(x: 1.36543*width, y: 0.01271*height), control2: CGPoint(x: 1.3799*width, y: -0.11018*height))
        path.addCurve(to: CGPoint(x: 1.38217*width, y: -0.22248*height), control1: CGPoint(x: 1.38506*width, y: -0.21082*height), control2: CGPoint(x: 1.38465*width, y: -0.21824*height))
        path.addLine(to: CGPoint(x: 1.37411*width, y: -0.23519*height))
        path.addCurve(to: CGPoint(x: 1.36936*width, y: -0.22248*height), control1: CGPoint(x: 1.37163*width, y: -0.23943*height), control2: CGPoint(x: 1.37018*width, y: -0.23519*height))
        path.closeSubpath()
        path.move(to: CGPoint(x: 1.45862*width, y: -0.22248*height))
        path.addLine(to: CGPoint(x: 1.45056*width, y: -0.23519*height))
        path.addCurve(to: CGPoint(x: 1.44539*width, y: -0.21824*height), control1: CGPoint(x: 1.44787*width, y: -0.23943*height), control2: CGPoint(x: 1.44705*width, y: -0.23413*height))
        path.addCurve(to: CGPoint(x: 1.41253*width, y: -0.09429*height), control1: CGPoint(x: 1.4363*width, y: -0.13666*height), control2: CGPoint(x: 1.42514*width, y: -0.09429*height))
        path.addCurve(to: CGPoint(x: 1.39455*width, y: -0.22036*height), control1: CGPoint(x: 1.39703*width, y: -0.09429*height), control2: CGPoint(x: 1.39166*width, y: -0.15573*height))
        path.addCurve(to: CGPoint(x: 1.41956*width, y: -0.32948*height), control1: CGPoint(x: 1.39744*width, y: -0.28498*height), control2: CGPoint(x: 1.40778*width, y: -0.32948*height))
        path.addCurve(to: CGPoint(x: 1.42968*width, y: -0.31783*height), control1: CGPoint(x: 1.42348*width, y: -0.32948*height), control2: CGPoint(x: 1.427*width, y: -0.32418*height))
        path.addCurve(to: CGPoint(x: 1.43506*width, y: -0.32312*height), control1: CGPoint(x: 1.43216*width, y: -0.31253*height), control2: CGPoint(x: 1.4332*width, y: -0.31253*height))
        path.addLine(to: CGPoint(x: 1.44126*width, y: -0.3602*height))
        path.addCurve(to: CGPoint(x: 1.44043*width, y: -0.38987*height), control1: CGPoint(x: 1.44271*width, y: -0.36974*height), control2: CGPoint(x: 1.44312*width, y: -0.37609*height))
        path.addCurve(to: CGPoint(x: 1.4148*width, y: -0.43648*height), control1: CGPoint(x: 1.43568*width, y: -0.41211*height), control2: CGPoint(x: 1.42576*width, y: -0.43648*height))
        path.addCurve(to: CGPoint(x: 1.36768*width, y: -0.2246*height), control1: CGPoint(x: 1.39455*width, y: -0.43648*height), control2: CGPoint(x: 1.37202*width, y: -0.3549*height))
        path.addCurve(to: CGPoint(x: 1.40592*width, y: 0.01271*height), control1: CGPoint(x: 1.36355*width, y: -0.09535*height), control2: CGPoint(x: 1.37926*width, y: 0.01271*height))
        path.addCurve(to: CGPoint(x: 1.46089*width, y: -0.19917*height), control1: CGPoint(x: 1.42968*width, y: 0.01271*height), control2: CGPoint(x: 1.45139*width, y: -0.0731*height))
        path.addCurve(to: CGPoint(x: 1.45862*width, y: -0.22248*height), control1: CGPoint(x: 1.46172*width, y: -0.21082*height), control2: CGPoint(x: 1.4611*width, y: -0.21824*height))
        path.closeSubpath()
        path.move(to: CGPoint(x: 1.52396*width, y: -0.22354*height))
        path.addLine(to: CGPoint(x: 1.5159*width, y: -0.23625*height))
        path.addCurve(to: CGPoint(x: 1.51114*width, y: -0.22566*height), control1: CGPoint(x: 1.51362*width, y: -0.23943*height), control2: CGPoint(x: 1.51218*width, y: -0.23731*height))
        path.addCurve(to: CGPoint(x: 1.48428*width, y: -0.09641*height), control1: CGPoint(x: 1.50164*width, y: -0.12395*height), control2: CGPoint(x: 1.4911*width, y: -0.09641*height))
        path.addCurve(to: CGPoint(x: 1.46692*width, y: -0.25214*height), control1: CGPoint(x: 1.47312*width, y: -0.09641*height), control2: CGPoint(x: 1.46754*width, y: -0.17374*height))
        path.addCurve(to: CGPoint(x: 1.51301*width, y: -0.44284*height), control1: CGPoint(x: 1.48325*width, y: -0.27333*height), control2: CGPoint(x: 1.50267*width, y: -0.33372*height))
        path.addCurve(to: CGPoint(x: 1.49813*width, y: -0.70133*height), control1: CGPoint(x: 1.52231*width, y: -0.54242*height), control2: CGPoint(x: 1.52603*width, y: -0.70133*height))
        path.addCurve(to: CGPoint(x: 1.44584*width, y: -0.36762*height), control1: CGPoint(x: 1.47705*width, y: -0.70133*height), control2: CGPoint(x: 1.45452*width, y: -0.57314*height))
        path.addCurve(to: CGPoint(x: 1.47829*width, y: 0.01271*height), control1: CGPoint(x: 1.43922*width, y: -0.21188*height), control2: CGPoint(x: 1.44294*width, y: 0.01271*height))
        path.addCurve(to: CGPoint(x: 1.52499*width, y: -0.18964*height), control1: CGPoint(x: 1.49854*width, y: 0.01271*height), control2: CGPoint(x: 1.51569*width, y: -0.06145*height))
        path.addCurve(to: CGPoint(x: 1.52396*width, y: -0.22354*height), control1: CGPoint(x: 1.52665*width, y: -0.21082*height), control2: CGPoint(x: 1.52685*width, y: -0.21824*height))
        path.closeSubpath()
        path.move(to: CGPoint(x: 1.46878*width, y: -0.34961*height))
        path.addCurve(to: CGPoint(x: 1.49523*width, y: -0.59221*height), control1: CGPoint(x: 1.47394*width, y: -0.47462*height), control2: CGPoint(x: 1.488*width, y: -0.5901*height))
        path.addCurve(to: CGPoint(x: 1.49296*width, y: -0.46508*height), control1: CGPoint(x: 1.5006*width, y: -0.59327*height), control2: CGPoint(x: 1.49957*width, y: -0.52759*height))
        path.addCurve(to: CGPoint(x: 1.46878*width, y: -0.34961*height), control1: CGPoint(x: 1.48655*width, y: -0.40258*height), control2: CGPoint(x: 1.47684*width, y: -0.36444*height))
        path.closeSubpath()
        path.move(to: CGPoint(x: 1.58615*width, y: -0.214*height))
        path.addCurve(to: CGPoint(x: 1.55101*width, y: -0.09641*height), control1: CGPoint(x: 1.5783*width, y: -0.13137*height), control2: CGPoint(x: 1.56362*width, y: -0.09641*height))
        path.addCurve(to: CGPoint(x: 1.53366*width, y: -0.14302*height), control1: CGPoint(x: 1.54213*width, y: -0.09641*height), control2: CGPoint(x: 1.53655*width, y: -0.11442*height))
        path.addCurve(to: CGPoint(x: 1.58119*width, y: -0.28604*height), control1: CGPoint(x: 1.55164*width, y: -0.1409*height), control2: CGPoint(x: 1.57644*width, y: -0.18434*height))
        path.addCurve(to: CGPoint(x: 1.55391*width, y: -0.43648*height), control1: CGPoint(x: 1.58533*width, y: -0.37186*height), control2: CGPoint(x: 1.57251*width, y: -0.43648*height))
        path.addCurve(to: CGPoint(x: 1.50555*width, y: -0.23095*height), control1: CGPoint(x: 1.53324*width, y: -0.43648*height), control2: CGPoint(x: 1.51051*width, y: -0.35702*height))
        path.addCurve(to: CGPoint(x: 1.54647*width, y: 0.01271*height), control1: CGPoint(x: 1.49997*width, y: -0.09323*height), control2: CGPoint(x: 1.5194*width, y: 0.01271*height))
        path.addCurve(to: CGPoint(x: 1.60207*width, y: -0.19917*height), control1: CGPoint(x: 1.57231*width, y: 0.01271*height), control2: CGPoint(x: 1.5938*width, y: -0.08263*height))
        path.addCurve(to: CGPoint(x: 1.59979*width, y: -0.22248*height), control1: CGPoint(x: 1.60289*width, y: -0.21082*height), control2: CGPoint(x: 1.60227*width, y: -0.21824*height))
        path.addLine(to: CGPoint(x: 1.59173*width, y: -0.23519*height))
        path.addCurve(to: CGPoint(x: 1.58615*width, y: -0.214*height), control1: CGPoint(x: 1.58925*width, y: -0.23943*height), control2: CGPoint(x: 1.58822*width, y: -0.23519*height))
        path.closeSubpath()
        path.move(to: CGPoint(x: 1.5318*width, y: -0.20659*height))
        path.addCurve(to: CGPoint(x: 1.532*width, y: -0.214*height), control1: CGPoint(x: 1.5318*width, y: -0.20871*height), control2: CGPoint(x: 1.532*width, y: -0.21188*height))
        path.addCurve(to: CGPoint(x: 1.55329*width, y: -0.32736*height), control1: CGPoint(x: 1.53428*width, y: -0.27863*height), control2: CGPoint(x: 1.54544*width, y: -0.32736*height))
        path.addCurve(to: CGPoint(x: 1.5597*width, y: -0.2977*height), control1: CGPoint(x: 1.55742*width, y: -0.32736*height), control2: CGPoint(x: 1.5597*width, y: -0.31465*height))
        path.addCurve(to: CGPoint(x: 1.5318*width, y: -0.20659*height), control1: CGPoint(x: 1.5597*width, y: -0.25426*height), control2: CGPoint(x: 1.54585*width, y: -0.20976*height))
        path.closeSubpath()
        path.move(to: CGPoint(x: 1.61481*width, y: 0.01271*height))
        path.addCurve(to: CGPoint(x: 1.64643*width, y: -0.0678*height), control1: CGPoint(x: 1.63011*width, y: 0.01271*height), control2: CGPoint(x: 1.64189*width, y: -0.0339*height))
        path.addCurve(to: CGPoint(x: 1.66958*width, y: 0.01271*height), control1: CGPoint(x: 1.64953*width, y: -0.01907*height), control2: CGPoint(x: 1.6578*width, y: 0.01271*height))
        path.addCurve(to: CGPoint(x: 1.7105*width, y: -0.19917*height), control1: CGPoint(x: 1.69273*width, y: 0.01271*height), control2: CGPoint(x: 1.70596*width, y: -0.11018*height))
        path.addCurve(to: CGPoint(x: 1.70823*width, y: -0.22248*height), control1: CGPoint(x: 1.71112*width, y: -0.21082*height), control2: CGPoint(x: 1.71071*width, y: -0.21824*height))
        path.addLine(to: CGPoint(x: 1.70017*width, y: -0.23519*height))
        path.addCurve(to: CGPoint(x: 1.69542*width, y: -0.22248*height), control1: CGPoint(x: 1.69769*width, y: -0.23943*height), control2: CGPoint(x: 1.69624*width, y: -0.23519*height))
        path.addCurve(to: CGPoint(x: 1.67599*width, y: -0.09429*height), control1: CGPoint(x: 1.69252*width, y: -0.18328*height), control2: CGPoint(x: 1.68549*width, y: -0.09429*height))
        path.addCurve(to: CGPoint(x: 1.67123*width, y: -0.18434*height), control1: CGPoint(x: 1.6702*width, y: -0.09429*height), control2: CGPoint(x: 1.66958*width, y: -0.12819*height))
        path.addLine(to: CGPoint(x: 1.67785*width, y: -0.40258*height))
        path.addCurve(to: CGPoint(x: 1.67433*width, y: -0.42377*height), control1: CGPoint(x: 1.67826*width, y: -0.41423*height), control2: CGPoint(x: 1.67681*width, y: -0.42377*height))
        path.addLine(to: CGPoint(x: 1.6578*width, y: -0.42377*height))
        path.addCurve(to: CGPoint(x: 1.65305*width, y: -0.40258*height), control1: CGPoint(x: 1.65532*width, y: -0.42377*height), control2: CGPoint(x: 1.65346*width, y: -0.41529*height))
        path.addLine(to: CGPoint(x: 1.65284*width, y: -0.39622*height))
        path.addCurve(to: CGPoint(x: 1.63176*width, y: -0.43648*height), control1: CGPoint(x: 1.64953*width, y: -0.41105*height), control2: CGPoint(x: 1.64292*width, y: -0.43648*height))
        path.addCurve(to: CGPoint(x: 1.5867*width, y: -0.24473*height), control1: CGPoint(x: 1.61171*width, y: -0.43648*height), control2: CGPoint(x: 1.59332*width, y: -0.35596*height))
        path.addCurve(to: CGPoint(x: 1.61481*width, y: 0.01271*height), control1: CGPoint(x: 1.57926*width, y: -0.11865*height), control2: CGPoint(x: 1.58918*width, y: 0.01271*height))
        path.closeSubpath()
        path.move(to: CGPoint(x: 1.64974*width, y: -0.29346*height))
        path.addCurve(to: CGPoint(x: 1.62308*width, y: -0.09429*height), control1: CGPoint(x: 1.64685*width, y: -0.18858*height), control2: CGPoint(x: 1.63589*width, y: -0.09429*height))
        path.addCurve(to: CGPoint(x: 1.61212*width, y: -0.21294*height), control1: CGPoint(x: 1.61336*width, y: -0.09429*height), control2: CGPoint(x: 1.60902*width, y: -0.15044*height))
        path.addCurve(to: CGPoint(x: 1.63651*width, y: -0.3263*height), control1: CGPoint(x: 1.61585*width, y: -0.28604*height), control2: CGPoint(x: 1.62639*width, y: -0.3263*height))
        path.addCurve(to: CGPoint(x: 1.64974*width, y: -0.29346*height), control1: CGPoint(x: 1.64375*width, y: -0.3263*height), control2: CGPoint(x: 1.64767*width, y: -0.30511*height))
        path.closeSubpath()
        path.move(to: CGPoint(x: 1.68931*width, y: -0.02119*height))
        path.addCurve(to: CGPoint(x: 1.69282*width, y: 0), control1: CGPoint(x: 1.6891*width, y: -0.00953*height), control2: CGPoint(x: 1.69055*width, y: 0))
        path.addLine(to: CGPoint(x: 1.70935*width, y: 0))
        path.addCurve(to: CGPoint(x: 1.71411*width, y: -0.02119*height), control1: CGPoint(x: 1.71225*width, y: 0), control2: CGPoint(x: 1.71369*width, y: -0.00848*height))
        path.addLine(to: CGPoint(x: 1.71597*width, y: -0.08263*height))
        path.addCurve(to: CGPoint(x: 1.74366*width, y: -0.31677*height), control1: CGPoint(x: 1.71886*width, y: -0.17798*height), control2: CGPoint(x: 1.73292*width, y: -0.31677*height))
        path.addCurve(to: CGPoint(x: 1.748*width, y: -0.2532*height), control1: CGPoint(x: 1.74821*width, y: -0.31677*height), control2: CGPoint(x: 1.74924*width, y: -0.29346*height))
        path.addLine(to: CGPoint(x: 1.7447*width, y: -0.14832*height))
        path.addCurve(to: CGPoint(x: 1.76888*width, y: 0.01271*height), control1: CGPoint(x: 1.74201*width, y: -0.05933*height), control2: CGPoint(x: 1.7511*width, y: 0.01271*height))
        path.addCurve(to: CGPoint(x: 1.8098*width, y: -0.19917*height), control1: CGPoint(x: 1.79202*width, y: 0.01271*height), control2: CGPoint(x: 1.80525*width, y: -0.11018*height))
        path.addCurve(to: CGPoint(x: 1.80753*width, y: -0.22248*height), control1: CGPoint(x: 1.81042*width, y: -0.21082*height), control2: CGPoint(x: 1.81001*width, y: -0.21824*height))
        path.addLine(to: CGPoint(x: 1.79946*width, y: -0.23519*height))
        path.addCurve(to: CGPoint(x: 1.79471*width, y: -0.22248*height), control1: CGPoint(x: 1.79698*width, y: -0.23943*height), control2: CGPoint(x: 1.79574*width, y: -0.23519*height))
        path.addCurve(to: CGPoint(x: 1.77528*width, y: -0.09429*height), control1: CGPoint(x: 1.79161*width, y: -0.18328*height), control2: CGPoint(x: 1.78479*width, y: -0.09429*height))
        path.addCurve(to: CGPoint(x: 1.77053*width, y: -0.18434*height), control1: CGPoint(x: 1.7695*width, y: -0.09429*height), control2: CGPoint(x: 1.76888*width, y: -0.12819*height))
        path.addLine(to: CGPoint(x: 1.7728*width, y: -0.26274*height))
        path.addCurve(to: CGPoint(x: 1.75358*width, y: -0.43648*height), control1: CGPoint(x: 1.7759*width, y: -0.35914*height), control2: CGPoint(x: 1.77032*width, y: -0.43648*height))
        path.addCurve(to: CGPoint(x: 1.72403*width, y: -0.34749*height), control1: CGPoint(x: 1.74056*width, y: -0.43648*height), control2: CGPoint(x: 1.73044*width, y: -0.39092*height))
        path.addLine(to: CGPoint(x: 1.72568*width, y: -0.40258*height))
        path.addCurve(to: CGPoint(x: 1.72217*width, y: -0.42377*height), control1: CGPoint(x: 1.7261*width, y: -0.41423*height), control2: CGPoint(x: 1.72465*width, y: -0.42377*height))
        path.addLine(to: CGPoint(x: 1.70584*width, y: -0.42377*height))
        path.addCurve(to: CGPoint(x: 1.70109*width, y: -0.40258*height), control1: CGPoint(x: 1.70336*width, y: -0.42377*height), control2: CGPoint(x: 1.7015*width, y: -0.41529*height))
        path.closeSubpath()
        path.move(to: CGPoint(x: 1.87397*width, y: -0.214*height))
        path.addCurve(to: CGPoint(x: 1.83883*width, y: -0.09641*height), control1: CGPoint(x: 1.86611*width, y: -0.13137*height), control2: CGPoint(x: 1.85144*width, y: -0.09641*height))
        path.addCurve(to: CGPoint(x: 1.82147*width, y: -0.14302*height), control1: CGPoint(x: 1.82994*width, y: -0.09641*height), control2: CGPoint(x: 1.82436*width, y: -0.11442*height))
        path.addCurve(to: CGPoint(x: 1.86901*width, y: -0.28604*height), control1: CGPoint(x: 1.83945*width, y: -0.1409*height), control2: CGPoint(x: 1.86425*width, y: -0.18434*height))
        path.addCurve(to: CGPoint(x: 1.84172*width, y: -0.43648*height), control1: CGPoint(x: 1.87314*width, y: -0.37186*height), control2: CGPoint(x: 1.86032*width, y: -0.43648*height))
        path.addCurve(to: CGPoint(x: 1.79336*width, y: -0.23095*height), control1: CGPoint(x: 1.82105*width, y: -0.43648*height), control2: CGPoint(x: 1.79832*width, y: -0.35702*height))
        path.addCurve(to: CGPoint(x: 1.83428*width, y: 0.01271*height), control1: CGPoint(x: 1.78778*width, y: -0.09323*height), control2: CGPoint(x: 1.80721*width, y: 0.01271*height))
        path.addCurve(to: CGPoint(x: 1.88988*width, y: -0.19917*height), control1: CGPoint(x: 1.86012*width, y: 0.01271*height), control2: CGPoint(x: 1.88161*width, y: -0.08263*height))
        path.addCurve(to: CGPoint(x: 1.8876*width, y: -0.22248*height), control1: CGPoint(x: 1.8907*width, y: -0.21082*height), control2: CGPoint(x: 1.89008*width, y: -0.21824*height))
        path.addLine(to: CGPoint(x: 1.87954*width, y: -0.23519*height))
        path.addCurve(to: CGPoint(x: 1.87396*width, y: -0.214*height), control1: CGPoint(x: 1.87706*width, y: -0.23943*height), control2: CGPoint(x: 1.87603*width, y: -0.23519*height))
        path.closeSubpath()
        path.move(to: CGPoint(x: 1.81961*width, y: -0.20659*height))
        path.addCurve(to: CGPoint(x: 1.81982*width, y: -0.214*height), control1: CGPoint(x: 1.81961*width, y: -0.20871*height), control2: CGPoint(x: 1.81982*width, y: -0.21188*height))
        path.addCurve(to: CGPoint(x: 1.8411*width, y: -0.32736*height), control1: CGPoint(x: 1.82209*width, y: -0.27863*height), control2: CGPoint(x: 1.83325*width, y: -0.32736*height))
        path.addCurve(to: CGPoint(x: 1.84751*width, y: -0.2977*height), control1: CGPoint(x: 1.84524*width, y: -0.32736*height), control2: CGPoint(x: 1.84751*width, y: -0.31465*height))
        path.addCurve(to: CGPoint(x: 1.81961*width, y: -0.20659*height), control1: CGPoint(x: 1.84751*width, y: -0.25426*height), control2: CGPoint(x: 1.83366*width, y: -0.20976*height))
        path.closeSubpath()
        path.move(to: CGPoint(x: 1.95305*width, y: -0.22248*height))
        path.addCurve(to: CGPoint(x: 1.93177*width, y: -0.09429*height), control1: CGPoint(x: 1.94995*width, y: -0.17904*height), control2: CGPoint(x: 1.94169*width, y: -0.09429*height))
        path.addCurve(to: CGPoint(x: 1.92598*width, y: -0.16527*height), control1: CGPoint(x: 1.92701*width, y: -0.09429*height), control2: CGPoint(x: 1.92371*width, y: -0.11442*height))
        path.addCurve(to: CGPoint(x: 1.93342*width, y: -0.31253*height), control1: CGPoint(x: 1.92867*width, y: -0.22777*height), control2: CGPoint(x: 1.93301*width, y: -0.30405*height))
        path.addCurve(to: CGPoint(x: 1.92763*width, y: -0.38245*height), control1: CGPoint(x: 1.93487*width, y: -0.34749*height), control2: CGPoint(x: 1.93445*width, y: -0.36656*height))
        path.addCurve(to: CGPoint(x: 1.8987*width, y: -0.44813*height), control1: CGPoint(x: 1.9173*width, y: -0.40576*height), control2: CGPoint(x: 1.90469*width, y: -0.42589*height))
        path.addCurve(to: CGPoint(x: 1.88692*width, y: -0.52017*height), control1: CGPoint(x: 1.89911*width, y: -0.48945*height), control2: CGPoint(x: 1.89498*width, y: -0.52441*height))
        path.addCurve(to: CGPoint(x: 1.87865*width, y: -0.40258*height), control1: CGPoint(x: 1.87762*width, y: -0.51594*height), control2: CGPoint(x: 1.87369*width, y: -0.46508*height))
        path.addCurve(to: CGPoint(x: 1.87431*width, y: -0.21506*height), control1: CGPoint(x: 1.87989*width, y: -0.3655*height), control2: CGPoint(x: 1.87906*width, y: -0.27969*height))
        path.addCurve(to: CGPoint(x: 1.87576*width, y: -0.19493*height), control1: CGPoint(x: 1.87348*width, y: -0.20553*height), control2: CGPoint(x: 1.8739*width, y: -0.19811*height))
        path.addLine(to: CGPoint(x: 1.88547*width, y: -0.17586*height))
        path.addCurve(to: CGPoint(x: 1.88919*width, y: -0.18434*height), control1: CGPoint(x: 1.88733*width, y: -0.17268*height), control2: CGPoint(x: 1.88857*width, y: -0.17374*height))
        path.addCurve(to: CGPoint(x: 1.8958*width, y: -0.35279*height), control1: CGPoint(x: 1.89229*width, y: -0.23519*height), control2: CGPoint(x: 1.89456*width, y: -0.29346*height))
        path.addLine(to: CGPoint(x: 1.90386*width, y: -0.33372*height))
        path.addCurve(to: CGPoint(x: 1.90717*width, y: -0.29664*height), control1: CGPoint(x: 1.90717*width, y: -0.3263*height), control2: CGPoint(x: 1.9082*width, y: -0.31783*height))
        path.addCurve(to: CGPoint(x: 1.89952*width, y: -0.14408*height), control1: CGPoint(x: 1.90448*width, y: -0.23625*height), control2: CGPoint(x: 1.90118*width, y: -0.19387*height))
        path.addCurve(to: CGPoint(x: 1.9266*width, y: 0.01271*height), control1: CGPoint(x: 1.89704*width, y: -0.06145*height), control2: CGPoint(x: 1.90924*width, y: 0.01271*height))
        path.addCurve(to: CGPoint(x: 1.96814*width, y: -0.19917*height), control1: CGPoint(x: 1.94913*width, y: 0.01271*height), control2: CGPoint(x: 1.96359*width, y: -0.11018*height))
        path.addCurve(to: CGPoint(x: 1.96587*width, y: -0.22248*height), control1: CGPoint(x: 1.96876*width, y: -0.21082*height), control2: CGPoint(x: 1.96835*width, y: -0.21824*height))
        path.addLine(to: CGPoint(x: 1.95781*width, y: -0.23519*height))
        path.addCurve(to: CGPoint(x: 1.95305*width, y: -0.22248*height), control1: CGPoint(x: 1.95533*width, y: -0.23943*height), control2: CGPoint(x: 1.95388*width, y: -0.23519*height))
        path.closeSubpath()
        return path
    }
}

// Ghost
struct Ghost: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.size.width
        let height = rect.size.height
        path.move(to: CGPoint(x: 0.47*width, y: 0.0815*height))
        path.addCurve(to: CGPoint(x: 0.3148*width, y: 0.1708*height), control1: CGPoint(x: 0.4054*width, y: 0.0893*height), control2: CGPoint(x: 0.353*width, y: 0.1195*height))
        path.addCurve(to: CGPoint(x: 0.2539*width, y: 0.3318*height), control1: CGPoint(x: 0.2841*width, y: 0.2119*height), control2: CGPoint(x: 0.2634*width, y: 0.2668*height))
        path.addCurve(to: CGPoint(x: 0.2517*width, y: 0.4035*height), control1: CGPoint(x: 0.2515*width, y: 0.3483*height), control2: CGPoint(x: 0.2504*width, y: 0.3846*height))
        path.addCurve(to: CGPoint(x: 0.2525*width, y: 0.4167*height), control1: CGPoint(x: 0.2522*width, y: 0.4106*height), control2: CGPoint(x: 0.2526*width, y: 0.4166*height))
        path.addCurve(to: CGPoint(x: 0.2447*width, y: 0.4189*height), control1: CGPoint(x: 0.2524*width, y: 0.4169*height), control2: CGPoint(x: 0.2489*width, y: 0.4179*height))
        path.addCurve(to: CGPoint(x: 0.1841*width, y: 0.4547*height), control1: CGPoint(x: 0.2245*width, y: 0.4241*height), control2: CGPoint(x: 0.2051*width, y: 0.4355*height))
        path.addCurve(to: CGPoint(x: 0.15*width, y: 0.513*height), control1: CGPoint(x: 0.1646*width, y: 0.4723*height), control2: CGPoint(x: 0.15*width, y: 0.4974*height))
        path.addCurve(to: CGPoint(x: 0.1569*width, y: 0.5309*height), control1: CGPoint(x: 0.15*width, y: 0.5195*height), control2: CGPoint(x: 0.1528*width, y: 0.5268*height))
        path.addCurve(to: CGPoint(x: 0.2085*width, y: 0.5309*height), control1: CGPoint(x: 0.165*width, y: 0.539*height), control2: CGPoint(x: 0.1775*width, y: 0.539*height))
        path.addCurve(to: CGPoint(x: 0.264*width, y: 0.5252*height), control1: CGPoint(x: 0.2538*width, y: 0.5191*height), control2: CGPoint(x: 0.2539*width, y: 0.5191*height))
        path.addCurve(to: CGPoint(x: 0.272*width, y: 0.5335*height), control1: CGPoint(x: 0.2701*width, y: 0.529*height), control2: CGPoint(x: 0.2711*width, y: 0.53*height))
        path.addCurve(to: CGPoint(x: 0.4178*width, y: 0.7853*height), control1: CGPoint(x: 0.3036*width, y: 0.6544*height), control2: CGPoint(x: 0.355*width, y: 0.7433*height))
        path.addCurve(to: CGPoint(x: 0.5902*width, y: 0.7895*height), control1: CGPoint(x: 0.4685*width, y: 0.8193*height), control2: CGPoint(x: 0.5271*width, y: 0.8207*height))
        path.addCurve(to: CGPoint(x: 0.6492*width, y: 0.7534*height), control1: CGPoint(x: 0.6081*width, y: 0.7807*height), control2: CGPoint(x: 0.6235*width, y: 0.7713*height))
        path.addCurve(to: CGPoint(x: 0.7453*width, y: 0.709*height), control1: CGPoint(x: 0.7026*width, y: 0.7165*height), control2: CGPoint(x: 0.7188*width, y: 0.709*height))
        path.addCurve(to: CGPoint(x: 0.8012*width, y: 0.7341*height), control1: CGPoint(x: 0.7664*width, y: 0.709*height), control2: CGPoint(x: 0.7842*width, y: 0.717*height))
        path.addCurve(to: CGPoint(x: 0.816*width, y: 0.744*height), control1: CGPoint(x: 0.81*width, y: 0.7429*height), control2: CGPoint(x: 0.8116*width, y: 0.744*height))
        path.addCurve(to: CGPoint(x: 0.8269*width, y: 0.7335*height), control1: CGPoint(x: 0.8201*width, y: 0.744*height), control2: CGPoint(x: 0.8254*width, y: 0.7389*height))
        path.addCurve(to: CGPoint(x: 0.8265*width, y: 0.707*height), control1: CGPoint(x: 0.8284*width, y: 0.7278*height), control2: CGPoint(x: 0.8283*width, y: 0.7154*height))
        path.addCurve(to: CGPoint(x: 0.7937*width, y: 0.6544*height), control1: CGPoint(x: 0.8223*width, y: 0.687*height), control2: CGPoint(x: 0.8115*width, y: 0.6696*height))
        path.addCurve(to: CGPoint(x: 0.7576*width, y: 0.6304*height), control1: CGPoint(x: 0.7808*width, y: 0.6433*height), control2: CGPoint(x: 0.7711*width, y: 0.6369*height))
        path.addCurve(to: CGPoint(x: 0.6647*width, y: 0.6285*height), control1: CGPoint(x: 0.725*width, y: 0.6149*height), control2: CGPoint(x: 0.6977*width, y: 0.6143*height))
        path.addCurve(to: CGPoint(x: 0.6694*width, y: 0.6162*height), control1: CGPoint(x: 0.6633*width, y: 0.6291*height), control2: CGPoint(x: 0.6646*width, y: 0.6257*height))
        path.addCurve(to: CGPoint(x: 0.7549*width, y: 0.3918*height), control1: CGPoint(x: 0.7139*width, y: 0.5273*height), control2: CGPoint(x: 0.7443*width, y: 0.4478*height))
        path.addCurve(to: CGPoint(x: 0.759*width, y: 0.31*height), control1: CGPoint(x: 0.76*width, y: 0.3651*height), control2: CGPoint(x: 0.7616*width, y: 0.3337*height))
        path.addCurve(to: CGPoint(x: 0.6846*width, y: 0.1554*height), control1: CGPoint(x: 0.7528*width, y: 0.252*height), control2: CGPoint(x: 0.7264*width, y: 0.1972*height))
        path.addCurve(to: CGPoint(x: 0.5329*width, y: 0.0815*height), control1: CGPoint(x: 0.6431*width, y: 0.114*height), control2: CGPoint(x: 0.5913*width, y: 0.0888*height))
        path.addCurve(to: CGPoint(x: 0.47*width, y: 0.0815*height), control1: CGPoint(x: 0.518*width, y: 0.0797*height), control2: CGPoint(x: 0.4851*width, y: 0.0797*height))
        path.closeSubpath()
        path.move(to: CGPoint(x: 0.534*width, y: 0.0985*height))
        path.addCurve(to: CGPoint(x: 0.6525*width, y: 0.1488*height), control1: CGPoint(x: 0.577*width, y: 0.1042*height), control2: CGPoint(x: 0.6175*width, y: 0.1214*height))
        path.addCurve(to: CGPoint(x: 0.6948*width, y: 0.1922*height), control1: CGPoint(x: 0.663*width, y: 0.157*height), control2: CGPoint(x: 0.6865*width, y: 0.1812*height))
        path.addCurve(to: CGPoint(x: 0.741*width, y: 0.374*height), control1: CGPoint(x: 0.7344*width, y: 0.245*height), control2: CGPoint(x: 0.7506*width, y: 0.3087*height))
        path.addCurve(to: CGPoint(x: 0.6504*width, y: 0.6166*height), control1: CGPoint(x: 0.732*width, y: 0.435*height), control2: CGPoint(x: 0.7061*width, y: 0.5045*height))
        path.addCurve(to: CGPoint(x: 0.6311*width, y: 0.6609*height), control1: CGPoint(x: 0.6311*width, y: 0.6556*height), control2: CGPoint(x: 0.6301*width, y: 0.6579*height))
        path.addCurve(to: CGPoint(x: 0.6403*width, y: 0.6664*height), control1: CGPoint(x: 0.6324*width, y: 0.6646*height), control2: CGPoint(x: 0.6371*width, y: 0.6674*height))
        path.addCurve(to: CGPoint(x: 0.6505*width, y: 0.6588*height), control1: CGPoint(x: 0.6415*width, y: 0.666*height), control2: CGPoint(x: 0.6461*width, y: 0.6626*height))
        path.addCurve(to: CGPoint(x: 0.704*width, y: 0.6353*height), control1: CGPoint(x: 0.6679*width, y: 0.6436*height), control2: CGPoint(x: 0.685*width, y: 0.6362*height))
        path.addCurve(to: CGPoint(x: 0.7833*width, y: 0.6673*height), control1: CGPoint(x: 0.7305*width, y: 0.634*height), control2: CGPoint(x: 0.757*width, y: 0.6447*height))
        path.addCurve(to: CGPoint(x: 0.8108*width, y: 0.7143*height), control1: CGPoint(x: 0.7983*width, y: 0.6803*height), control2: CGPoint(x: 0.8081*width, y: 0.6969*height))
        path.addCurve(to: CGPoint(x: 0.8101*width, y: 0.719*height), control1: CGPoint(x: 0.8116*width, y: 0.7193*height), control2: CGPoint(x: 0.8115*width, y: 0.7198*height))
        path.addCurve(to: CGPoint(x: 0.8065*width, y: 0.716*height), control1: CGPoint(x: 0.8092*width, y: 0.7186*height), control2: CGPoint(x: 0.8076*width, y: 0.7172*height))
        path.addCurve(to: CGPoint(x: 0.7675*width, y: 0.6948*height), control1: CGPoint(x: 0.8*width, y: 0.7088*height), control2: CGPoint(x: 0.7812*width, y: 0.6986*height))
        path.addCurve(to: CGPoint(x: 0.7209*width, y: 0.6953*height), control1: CGPoint(x: 0.7554*width, y: 0.6916*height), control2: CGPoint(x: 0.7341*width, y: 0.6918*height))
        path.addCurve(to: CGPoint(x: 0.6629*width, y: 0.724*height), control1: CGPoint(x: 0.7013*width, y: 0.7005*height), control2: CGPoint(x: 0.6868*width, y: 0.7076*height))
        path.addCurve(to: CGPoint(x: 0.5548*width, y: 0.7864*height), control1: CGPoint(x: 0.5998*width, y: 0.7672*height), control2: CGPoint(x: 0.583*width, y: 0.7769*height))
        path.addCurve(to: CGPoint(x: 0.508*width, y: 0.7947*height), control1: CGPoint(x: 0.5376*width, y: 0.7921*height), control2: CGPoint(x: 0.5265*width, y: 0.7941*height))
        path.addCurve(to: CGPoint(x: 0.4626*width, y: 0.7888*height), control1: CGPoint(x: 0.489*width, y: 0.7953*height), control2: CGPoint(x: 0.4788*width, y: 0.794*height))
        path.addCurve(to: CGPoint(x: 0.3776*width, y: 0.725*height), control1: CGPoint(x: 0.4334*width, y: 0.7796*height), control2: CGPoint(x: 0.4033*width, y: 0.757*height))
        path.addCurve(to: CGPoint(x: 0.3451*width, y: 0.6763*height), control1: CGPoint(x: 0.3696*width, y: 0.715*height), control2: CGPoint(x: 0.3525*width, y: 0.6894*height))
        path.addCurve(to: CGPoint(x: 0.2886*width, y: 0.5293*height), control1: CGPoint(x: 0.3234*width, y: 0.638*height), control2: CGPoint(x: 0.3017*width, y: 0.5813*height))
        path.addCurve(to: CGPoint(x: 0.2683*width, y: 0.3864*height), control1: CGPoint(x: 0.2758*width, y: 0.4785*height), control2: CGPoint(x: 0.2692*width, y: 0.4321*height))
        path.addCurve(to: CGPoint(x: 0.2726*width, y: 0.3205*height), control1: CGPoint(x: 0.2677*width, y: 0.3559*height), control2: CGPoint(x: 0.2684*width, y: 0.3444*height))
        path.addCurve(to: CGPoint(x: 0.4818*width, y: 0.097*height), control1: CGPoint(x: 0.2961*width, y: 0.1862*height), control2: CGPoint(x: 0.3708*width, y: 0.1063*height))
        path.addCurve(to: CGPoint(x: 0.534*width, y: 0.0985*height), control1: CGPoint(x: 0.4951*width, y: 0.0959*height), control2: CGPoint(x: 0.5201*width, y: 0.0966*height))
        path.closeSubpath()
        path.move(to: CGPoint(x: 0.2544*width, y: 0.4372*height))
        path.addCurve(to: CGPoint(x: 0.2575*width, y: 0.4589*height), control1: CGPoint(x: 0.2547*width, y: 0.439*height), control2: CGPoint(x: 0.2561*width, y: 0.4488*height))
        path.addCurve(to: CGPoint(x: 0.2656*width, y: 0.5051*height), control1: CGPoint(x: 0.2597*width, y: 0.4749*height), control2: CGPoint(x: 0.2642*width, y: 0.5003*height))
        path.addCurve(to: CGPoint(x: 0.2618*width, y: 0.5053*height), control1: CGPoint(x: 0.266*width, y: 0.5067*height), control2: CGPoint(x: 0.2657*width, y: 0.5067*height))
        path.addCurve(to: CGPoint(x: 0.2233*width, y: 0.5101*height), control1: CGPoint(x: 0.2554*width, y: 0.503*height), control2: CGPoint(x: 0.246*width, y: 0.5042*height))
        path.addCurve(to: CGPoint(x: 0.1775*width, y: 0.5205*height), control1: CGPoint(x: 0.1947*width, y: 0.5175*height), control2: CGPoint(x: 0.1846*width, y: 0.5198*height))
        path.addCurve(to: CGPoint(x: 0.169*width, y: 0.519*height), control1: CGPoint(x: 0.1718*width, y: 0.5211*height), control2: CGPoint(x: 0.171*width, y: 0.521*height))
        path.addCurve(to: CGPoint(x: 0.1791*width, y: 0.4849*height), control1: CGPoint(x: 0.1641*width, y: 0.5141*height), control2: CGPoint(x: 0.1686*width, y: 0.499*height))
        path.addCurve(to: CGPoint(x: 0.2285*width, y: 0.4427*height), control1: CGPoint(x: 0.1894*width, y: 0.4709*height), control2: CGPoint(x: 0.2135*width, y: 0.4504*height))
        path.addCurve(to: CGPoint(x: 0.2527*width, y: 0.434*height), control1: CGPoint(x: 0.2342*width, y: 0.4398*height), control2: CGPoint(x: 0.2501*width, y: 0.4341*height))
        path.addCurve(to: CGPoint(x: 0.2544*width, y: 0.4372*height), control1: CGPoint(x: 0.2534*width, y: 0.434*height), control2: CGPoint(x: 0.2541*width, y: 0.4355*height))
        path.closeSubpath()
        path.move(to: CGPoint(x: 0.4813*width, y: 0.2149*height))
        path.addCurve(to: CGPoint(x: 0.4432*width, y: 0.2634*height), control1: CGPoint(x: 0.4651*width, y: 0.2208*height), control2: CGPoint(x: 0.4513*width, y: 0.2383*height))
        path.addCurve(to: CGPoint(x: 0.4356*width, y: 0.312*height), control1: CGPoint(x: 0.4376*width, y: 0.2805*height), control2: CGPoint(x: 0.4356*width, y: 0.2933*height))
        path.addCurve(to: CGPoint(x: 0.4404*width, y: 0.3387*height), control1: CGPoint(x: 0.4356*width, y: 0.3288*height), control2: CGPoint(x: 0.4366*width, y: 0.3342*height))
        path.addCurve(to: CGPoint(x: 0.4655*width, y: 0.3364*height), control1: CGPoint(x: 0.4439*width, y: 0.3427*height), control2: CGPoint(x: 0.4488*width, y: 0.3423*height))
        path.addCurve(to: CGPoint(x: 0.492*width, y: 0.3315*height), control1: CGPoint(x: 0.4793*width, y: 0.3316*height), control2: CGPoint(x: 0.4796*width, y: 0.3316*height))
        path.addCurve(to: CGPoint(x: 0.5195*width, y: 0.3324*height), control1: CGPoint(x: 0.4989*width, y: 0.3315*height), control2: CGPoint(x: 0.5113*width, y: 0.3319*height))
        path.addCurve(to: CGPoint(x: 0.5466*width, y: 0.3276*height), control1: CGPoint(x: 0.5369*width, y: 0.3334*height), control2: CGPoint(x: 0.5416*width, y: 0.3326*height))
        path.addCurve(to: CGPoint(x: 0.552*width, y: 0.2905*height), control1: CGPoint(x: 0.5526*width, y: 0.3216*height), control2: CGPoint(x: 0.5542*width, y: 0.3104*height))
        path.addCurve(to: CGPoint(x: 0.516*width, y: 0.22*height), control1: CGPoint(x: 0.5484*width, y: 0.2589*height), control2: CGPoint(x: 0.5346*width, y: 0.2319*height))
        path.addCurve(to: CGPoint(x: 0.4813*width, y: 0.2149*height), control1: CGPoint(x: 0.5055*width, y: 0.2133*height), control2: CGPoint(x: 0.4916*width, y: 0.2112*height))
        path.closeSubpath()
        path.move(to: CGPoint(x: 0.3452*width, y: 0.2165*height))
        path.addCurve(to: CGPoint(x: 0.306*width, y: 0.2848*height), control1: CGPoint(x: 0.3275*width, y: 0.2247*height), control2: CGPoint(x: 0.3104*width, y: 0.2544*height))
        path.addCurve(to: CGPoint(x: 0.3052*width, y: 0.3052*height), control1: CGPoint(x: 0.3053*width, y: 0.2892*height), control2: CGPoint(x: 0.305*width, y: 0.2984*height))
        path.addCurve(to: CGPoint(x: 0.3129*width, y: 0.3277*height), control1: CGPoint(x: 0.3056*width, y: 0.3193*height), control2: CGPoint(x: 0.3072*width, y: 0.3239*height))
        path.addCurve(to: CGPoint(x: 0.3367*width, y: 0.3279*height), control1: CGPoint(x: 0.3171*width, y: 0.3306*height), control2: CGPoint(x: 0.3204*width, y: 0.3306*height))
        path.addCurve(to: CGPoint(x: 0.3708*width, y: 0.3305*height), control1: CGPoint(x: 0.3529*width, y: 0.3252*height), control2: CGPoint(x: 0.3592*width, y: 0.3257*height))
        path.addCurve(to: CGPoint(x: 0.3942*width, y: 0.3371*height), control1: CGPoint(x: 0.3862*width, y: 0.3369*height), control2: CGPoint(x: 0.3912*width, y: 0.3383*height))
        path.addCurve(to: CGPoint(x: 0.3985*width, y: 0.3331*height), control1: CGPoint(x: 0.3957*width, y: 0.3366*height), control2: CGPoint(x: 0.3976*width, y: 0.3347*height))
        path.addCurve(to: CGPoint(x: 0.3964*width, y: 0.2647*height), control1: CGPoint(x: 0.4036*width, y: 0.3231*height), control2: CGPoint(x: 0.4026*width, y: 0.2895*height))
        path.addCurve(to: CGPoint(x: 0.3657*width, y: 0.2155*height), control1: CGPoint(x: 0.39*width, y: 0.2389*height), control2: CGPoint(x: 0.3788*width, y: 0.221*height))
        path.addCurve(to: CGPoint(x: 0.3452*width, y: 0.2165*height), control1: CGPoint(x: 0.3601*width, y: 0.2132*height), control2: CGPoint(x: 0.3514*width, y: 0.2136*height))
        path.closeSubpath()
        path.move(to: CGPoint(x: 0.4847*width, y: 0.4141*height))
        path.addCurve(to: CGPoint(x: 0.4028*width, y: 0.4568*height), control1: CGPoint(x: 0.4575*width, y: 0.417*height), control2: CGPoint(x: 0.4287*width, y: 0.432*height))
        path.addCurve(to: CGPoint(x: 0.372*width, y: 0.5039*height), control1: CGPoint(x: 0.3864*width, y: 0.4726*height), control2: CGPoint(x: 0.3753*width, y: 0.4895*height))
        path.addCurve(to: CGPoint(x: 0.3808*width, y: 0.5335*height), control1: CGPoint(x: 0.3692*width, y: 0.5161*height), control2: CGPoint(x: 0.3726*width, y: 0.5277*height))
        path.addCurve(to: CGPoint(x: 0.4297*width, y: 0.5298*height), control1: CGPoint(x: 0.389*width, y: 0.5392*height), control2: CGPoint(x: 0.4035*width, y: 0.5381*height))
        path.addCurve(to: CGPoint(x: 0.463*width, y: 0.521*height), control1: CGPoint(x: 0.4497*width, y: 0.5235*height), control2: CGPoint(x: 0.4592*width, y: 0.521*height))
        path.addCurve(to: CGPoint(x: 0.4835*width, y: 0.5305*height), control1: CGPoint(x: 0.4655*width, y: 0.521*height), control2: CGPoint(x: 0.4712*width, y: 0.5237*height))
        path.addLine(to: CGPoint(x: 0.5004*width, y: 0.5399*height))
        path.addLine(to: CGPoint(x: 0.5042*width, y: 0.5332*height))
        path.addCurve(to: CGPoint(x: 0.508*width, y: 0.5258*height), control1: CGPoint(x: 0.5063*width, y: 0.5295*height), control2: CGPoint(x: 0.508*width, y: 0.5262*height))
        path.addCurve(to: CGPoint(x: 0.4681*width, y: 0.5044*height), control1: CGPoint(x: 0.508*width, y: 0.5246*height), control2: CGPoint(x: 0.4716*width, y: 0.505*height))
        path.addCurve(to: CGPoint(x: 0.4329*width, y: 0.5114*height), control1: CGPoint(x: 0.4626*width, y: 0.5033*height), control2: CGPoint(x: 0.4517*width, y: 0.5055*height))
        path.addCurve(to: CGPoint(x: 0.3905*width, y: 0.5196*height), control1: CGPoint(x: 0.4037*width, y: 0.5206*height), control2: CGPoint(x: 0.3946*width, y: 0.5223*height))
        path.addCurve(to: CGPoint(x: 0.388*width, y: 0.5122*height), control1: CGPoint(x: 0.3883*width, y: 0.5182*height), control2: CGPoint(x: 0.388*width, y: 0.5172*height))
        path.addCurve(to: CGPoint(x: 0.4404*width, y: 0.448*height), control1: CGPoint(x: 0.3881*width, y: 0.4946*height), control2: CGPoint(x: 0.4088*width, y: 0.4693*height))
        path.addCurve(to: CGPoint(x: 0.4875*width, y: 0.4309*height), control1: CGPoint(x: 0.4554*width, y: 0.438*height), control2: CGPoint(x: 0.4691*width, y: 0.433*height))
        path.addCurve(to: CGPoint(x: 0.5648*width, y: 0.4481*height), control1: CGPoint(x: 0.5106*width, y: 0.4283*height), control2: CGPoint(x: 0.5396*width, y: 0.4347*height))
        path.addCurve(to: CGPoint(x: 0.5766*width, y: 0.453*height), control1: CGPoint(x: 0.5699*width, y: 0.4508*height), control2: CGPoint(x: 0.5752*width, y: 0.453*height))
        path.addCurve(to: CGPoint(x: 0.584*width, y: 0.445*height), control1: CGPoint(x: 0.5801*width, y: 0.453*height), control2: CGPoint(x: 0.584*width, y: 0.4488*height))
        path.addCurve(to: CGPoint(x: 0.5658*width, y: 0.43*height), control1: CGPoint(x: 0.584*width, y: 0.4402*height), control2: CGPoint(x: 0.5797*width, y: 0.4367*height))
        path.addCurve(to: CGPoint(x: 0.5108*width, y: 0.414*height), control1: CGPoint(x: 0.5463*width, y: 0.4206*height), control2: CGPoint(x: 0.5309*width, y: 0.4161*height))
        path.addCurve(to: CGPoint(x: 0.4847*width, y: 0.4141*height), control1: CGPoint(x: 0.5003*width, y: 0.4129*height), control2: CGPoint(x: 0.4958*width, y: 0.4129*height))
        path.closeSubpath()
        path.move(to: CGPoint(x: 0.4665*width, y: 0.893*height))
        path.addCurve(to: CGPoint(x: 0.3071*width, y: 0.9064*height), control1: CGPoint(x: 0.3762*width, y: 0.8947*height), control2: CGPoint(x: 0.3136*width, y: 0.8999*height))
        path.addCurve(to: CGPoint(x: 0.3093*width, y: 0.9095*height), control1: CGPoint(x: 0.3058*width, y: 0.9078*height), control2: CGPoint(x: 0.306*width, y: 0.9081*height))
        path.addCurve(to: CGPoint(x: 0.6915*width, y: 0.9164*height), control1: CGPoint(x: 0.3396*width, y: 0.9221*height), control2: CGPoint(x: 0.5731*width, y: 0.9264*height))
        path.addCurve(to: CGPoint(x: 0.7394*width, y: 0.9075*height), control1: CGPoint(x: 0.7204*width, y: 0.914*height), control2: CGPoint(x: 0.7389*width, y: 0.9105*height))
        path.addCurve(to: CGPoint(x: 0.4665*width, y: 0.893*height), control1: CGPoint(x: 0.7408*width, y: 0.8978*height), control2: CGPoint(x: 0.604*width, y: 0.8905*height))
        path.closeSubpath()
        return path
    }
}

// Aurora
struct AuroraView: View {
    
    private enum AnimationProperties {
        static let animationSpeed: Double = 4
        static let timerDuration: TimeInterval = 3
        static let blurRadius: CGFloat = 130
    }
    
    @State private var timer = Timer.publish(every: AnimationProperties.timerDuration, on: .main, in: .common).autoconnect()
    @ObservedObject private var animator = CircleAnimator(colors: AuroraColors.all)
    
    var body: some View {
        ZStack {
            ZStack {
                ForEach(animator.circles) { circle in
                    MovingCircle(originOffset: circle.position)
                        .foregroundColor(circle.color)
                }
            }.blur(radius: AnimationProperties.blurRadius)
        }
        .onDisappear {
            timer.upstream.connect().cancel()
        }
        .onAppear {
            animateCircles()
            timer = Timer.publish(every: AnimationProperties.timerDuration, on: .main, in: .common).autoconnect()
        }
        .onReceive(timer) { _ in
            animateCircles()
        }
    }
    
    private func animateCircles() {
        withAnimation(.easeInOut(duration: AnimationProperties.animationSpeed)) {
            animator.animate()
        }
    }
    
}

private enum AuroraColors {
    static var all: [Color] {
        [
            //            Color(red: 0/255, green: 0/255, blue: 128/255), // Dark Blue
            Color.purple, // Purple
            Color.pink, // Pink
            Color.orange, // Orange
        ]
    }
}

private struct MovingCircle: Shape {
    
    var originOffset: CGPoint
    
    var animatableData: CGPoint.AnimatableData {
        get {
            originOffset.animatableData
        }
        set {
            originOffset.animatableData = newValue
        }
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let adjustedX = rect.width * originOffset.x
        let adjustedY = rect.height * originOffset.y
        let smallestDimension = min(rect.width, rect.height)
        path.addArc(center: CGPoint(x: adjustedX, y: adjustedY), radius: smallestDimension/2, startAngle: .zero, endAngle: .degrees(360), clockwise: true)
        return path
    }
}

private class CircleAnimator: ObservableObject {
    class Circle: Identifiable {
        internal init(position: CGPoint, color: Color) {
            self.position = position
            self.color = color
        }
        var position: CGPoint
        let id = UUID().uuidString
        let color: Color
    }
    
    @Published private(set) var circles: [Circle] = []
    
    
    init(colors: [Color]) {
        circles = colors.map({ color in
            Circle(position: CircleAnimator.generateRandomPosition(), color: color)
        })
    }
    
    func animate() {
        objectWillChange.send()
        for circle in circles {
            circle.position = CircleAnimator.generateRandomPosition()
        }
    }
    
    static func generateRandomPosition() -> CGPoint {
        CGPoint(x: CGFloat.random(in: 0 ... 1), y: CGFloat.random(in: 0 ... 1))
    }
}

// Ghost View
//                ZStack {
//                    LinearGradient(colors: [.pink, .orange], startPoint: .topLeading, endPoint: .bottomTrailing)
//                        .edgesIgnoringSafeArea(.all)
//                        .hueRotation(.degrees(animateGradient ? 45 : 0))
//                        .onAppear {
//                            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
//                                animateGradient.toggle()
//                            }
//                        }
//                        .mask(
//                            Ghost()
//                                .frame(width: 200, height: 200)
//                        )
//                }

// Gradient Background
//ZStack {
//    LinearGradient(colors: [.pink, .orange], startPoint: .topLeading, endPoint: .bottomTrailing)
//        .edgesIgnoringSafeArea(.all)
//        .hueRotation(.degrees(animateGradient ? 45 : 0))
//        .onAppear {
//            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
//                animateGradient.toggle()
//            }
//        }
//        .mask(
//            Ghost()
//                .frame(width: 200, height: 200)
//        )
//}
