<?php

namespace App\Classes\Validations;

use Illuminate\Http\Request;
use Spatie\WebhookClient\Exceptions\InvalidConfig;
use Spatie\WebhookClient\SignatureValidator\SignatureValidator;
use Spatie\WebhookClient\WebhookConfig;

class MercadopagoSignatureValidation implements SignatureValidator
{
    public function isValid(Request $request, WebhookConfig $config): bool
    {

        if (!$request->application_id || !$request->user_id) {
            return false;
        }

        $requestSecret = hash_hmac('sha256', $request->getContent(), $request->application_id . $request->user_id);
        logger($requestSecret);
        $signingSecret = $config->signingSecret;

        if (empty($signingSecret)) {
            throw InvalidConfig::signingSecretNotSet();
        }

        $computedSignature = hash_hmac('sha256', $request->getContent(), $signingSecret);

        return hash_equals($requestSecret, $computedSignature);
    }
}
