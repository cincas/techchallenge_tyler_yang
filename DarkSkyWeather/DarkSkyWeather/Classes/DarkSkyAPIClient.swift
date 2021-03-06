//  Copyright © 2017 Tyler Yang. All rights reserved.

import Foundation
import Result

enum APIError: Error {
  case malformedEndpoint, network(Error)
  case unknown
}

protocol DarkSkyAPIClient {
  func fetchForecastWith(latitude: Double, longitude: Double,
                         completionHandler: @escaping (Result<Forecast, APIError>) -> Void)
}

struct APIClient {
  let domain: String
  let apiKey: String
  let session: URLSession
  let defaultParameters = [
    "exclude": "hourly,currently,flags",
    "units": "si"
  ]
  
  init(apiKey: String,
       domain: String = "https://api.darksky.net/",
       session: URLSession = URLSession.shared) {
    self.domain = domain
    self.apiKey = apiKey
    self.session = session
  }
}

extension APIClient: DarkSkyAPIClient {
  func fetchForecastWith(latitude: Double, longitude: Double,
                         completionHandler: @escaping (Result<Forecast, APIError>) -> Void) {
    guard let urlRequest = urlRequestFor(path: "forecast",
                                         latitude: latitude,
                                         longitude: longitude) else {
                                          completionHandler(.failure(.malformedEndpoint))
                                          return
    }
    
    let dataTask = session.dataTask(with: urlRequest) { (data, response, error) in
      if let error = error {
        completionHandler(.failure(.network(error)))
        return
      }
      
      guard let data = data else {
        completionHandler(.failure(.unknown))
        return
      }
      
      let decoder = JSONDecoder()
      decoder.dateDecodingStrategy = .secondsSince1970
      guard let weeklyForecast = try? decoder.decode(Forecast.self, from: data) else {
        completionHandler(.failure(.unknown))
        return
      }
      
      completionHandler(.success(weeklyForecast))
    }
    
    dataTask.resume()
  }
}

extension APIClient {
  private func urlRequestFor(path: String, latitude: Double, longitude: Double) -> URLRequest? {
    guard var baseURL = URL(string: domain) else { return nil }
    [path, apiKey, "\(latitude),\(longitude)"].forEach {
      baseURL.appendPathComponent($0)
    }
    
    var urlComponents = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
    urlComponents?.queryItems = defaultParameters.flatMap {
      URLQueryItem(name: $0.key, value: String($0.value))
    }
    
    guard let url = urlComponents?.url else { return nil }
    return URLRequest(url: url)
  }
}
