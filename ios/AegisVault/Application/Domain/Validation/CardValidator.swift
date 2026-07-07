struct CardValidator: DomainValidator {
    func validate(_ aggregate: CardAggregate) throws {
        try aggregate.validateInvariants()
    }
}
