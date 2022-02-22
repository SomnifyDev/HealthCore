//
//  File.swift
//  
//
//  Created by Анас Бен Мустафа on 2/22/22.
//

import Foundation
import HealthKit

extension HKUnit {

    public class func countMin() -> Self {
        return self.init(from: "count/min")
    }

}

