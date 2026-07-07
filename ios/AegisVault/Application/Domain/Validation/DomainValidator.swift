protocol DomainValidator {
    associatedtype Aggregate

    func validate(_ aggregate: Aggregate) throws
}
