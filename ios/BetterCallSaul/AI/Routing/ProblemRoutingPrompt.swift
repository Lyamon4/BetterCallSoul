import Foundation

enum ProblemRoutingPrompt {
    static func make(request: ProblemRoutingRequest) -> String {
        let clarificationRule = request.clarificationAllowed
            ? "Если действительно подходят два или больше сценария, можно вернуть clarify с одним вопросом до 120 символов."
            : "Уточнение уже использовано: action clarify запрещён. Обязательно выбери наиболее подходящий route."
        let clarificationContext: String
        if let question = request.clarificationQuestion,
           let answer = request.clarificationAnswer {
            clarificationContext = """
            Предыдущий вопрос: \(question)
            Ответ пользователя: \(answer)
            """
        } else {
            clarificationContext = "Уточнений ещё не было."
        }

        return """
        Ты выбираешь только один подходящий сценарий BetterCallSaul.
        Допустимые case_type: charge, fine, subscription, product, bill.

        Значения:
        - charge: неизвестное или ошибочное разовое списание, возврат платежа;
        - fine: государственный, дорожный или парковочный штраф;
        - subscription: отмена подписки или её автоматического продления;
        - product: дефектный, некачественный или не доставленный товар;
        - bill: завышенный или неверный счёт за услуги.

        не давай юридических советов, не цитируй законы, не оценивай исход и не создавай документы.
        \(clarificationRule)
        Вопрос должен быть одним коротким предложением.
        Верни только JSON без пояснений:
        {"action":"route","case_type":"fine","question":null}
        или
        {"action":"clarify","case_type":null,"question":"Это разовый платёж или продление подписки?"}

        Различай: неизвестное списание и продление подписки; штраф и завышенный счёт; разовый возврат и отмену подписки; дефект товара и ошибочный счёт.

        Проблема пользователя: \(request.problem)
        \(clarificationContext)
        """
    }
}
