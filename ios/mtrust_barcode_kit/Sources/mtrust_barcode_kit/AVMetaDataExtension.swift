//
//  AVMetaDataExtension.swift
//  barcode_kit
//
//  Created by Yannick Stolle on 27.07.23.
//

import Foundation
import AVKit

// This extension is based upon https://www.thonky.com/qr-code-tutorial/data-encoding
extension AVMetadataMachineReadableCodeObject
{
  

    var rawValue: Data?
    {
        guard let descriptor = descriptor else
        {
            return nil
        }
        switch type
        {
            case .qr:
                return (descriptor as! CIQRCodeDescriptor).errorCorrectedPayload
            case .aztec:
                return (descriptor as! CIAztecCodeDescriptor).errorCorrectedPayload
            case .pdf417:
                return (descriptor as! CIPDF417CodeDescriptor).errorCorrectedPayload
            case .dataMatrix:
                return (descriptor as! CIDataMatrixCodeDescriptor).errorCorrectedPayload
            default:
                return stringValue?.data(using: String.Encoding.utf8)
        }
    }

    
}
