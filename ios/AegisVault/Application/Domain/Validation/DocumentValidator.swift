struct DocumentValidator: DomainValidator {
    func validate(_ aggregate: DocumentAggregate) throws {
        try aggregate.validateInvariants()
    }
}
