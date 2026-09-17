# عمل العضو ٤ — CI/CD

## الحالة

تم تجهيز المسار والتطبيق الحقيقي مع Dockerfile والاختبارات، ونجح التشغيل المحلي. لم يُشغّل المسار بعد على GitLab أو Runner، ولم يحدث نشر على Azure أو إرسال إشعار خارجي.
GitHub هو مصدر الكود؛ جذر مشروع GitLab يجب أن يحتوي **محتويات sample-app** مباشرة.

## اتفاق العضو ٣

- Node.js 24، وpackage-lock.json ملتزم في Git، وأمر `npm ci` ناجح.
- `npm test` يشغّل اختبارات حقيقية ويخرج برمز غير صفر عند الفشل. لا نستخدم `--if-present`.
- Dockerfile يبني التطبيق من المجلد الحالي، ويحتوي صورة التشغيل على Node.js لدعم healthcheck.
- التطبيق يستمع على `0.0.0.0:3000`، وGET /health يعيد HTTP 200 وJSON صالحًا.
- لا توجد حاليًا خطوة npm build متفق عليها؛ البناء هو `docker build`. أي تجميع مطلوب يضيفه عضو التطبيق إلى Dockerfile.

## المراحل

1. Build: يتحقق من lockfile، ويبني ويرفع صورة إلى GitLab Registry مرتبطة بمعرف commit الكامل.
2. Test: ينفذ npm ci وnpm test على نفس commit، في Node.js 24.
3. Security Scan: يفحص الصورة بـTrivy؛ أي ثغرة HIGH أو CRITICAL أو فشل تشغيل الفاحص يمنع النشر.
4. Deploy: يعمل فقط على الفرع الافتراضي المحمي وعند DEPLOY_ENABLED=true، بعد نجاح المراحل السابقة. يستخدم SSH وCompose على Docker في الخادم، وينتظر صحة التطبيق حتى 120 ثانية. النشرات متسلسلة عبر resource_group.
5. Notify: ينشئ pipeline-summary.txt مع رابط نتائج الوظائف حتى عند فشل مرحلة سابقة. **هذا تقرير داخل GitLab؛ إرسال Discord أو البريد غير منفذ** إلى حين الاتفاق على القناة. لا يعد نجاح هذه الوظيفة دليلًا على نشر التطبيق.

لا توجد allow_failure أو needs تتجاوز بوابات المراحل. رفع الصورة في Build لا ينشرها على الخادم.
فشل فحص الصحة يفشل النشر، لكنه لا يعيد الإصدار السابق تلقائيًا؛ قد تبقى الحاوية الجديدة غير سليمة. الاسترجاع مهمة تكامل لاحقة.

## متطلبات العضو ٢

- GitLab Container Registry مفعل ويمكن الوصول إليه بشهادة TLS موثوقة.
- Runner مخصص وموثوق بوسم foxflow وDocker executor، مع دعم Docker-in-Docker بوضع privileged ومشاركة `/certs/client` بين job وservice، وفق وثائق GitLab أدناه. لا تستخدم Docker socket binding مع هذا التصميم.
- تأكيد توفر إصدارات الصور المكتوبة في YAML في شبكتكم، ثم تثبيتها بالـdigest في مهمة التقوية لاحقًا.
- خادم النشر يحتوي Docker مع Compose يدعم `up --wait`؛ حساب النشر يستطيع الوصول إلى Docker عبر SSH.
- تأكيد هوية خادم SSH من مصدر موثوق وتسليم known_hosts؛ لا تعطّل التحقق من المضيف.
- حماية الفرع الافتراضي، وحصر أسرار النشر بالفرع المحمي وبيئة production.
- فتح APP_PORT في شبكة Azure عند الحاجة. Compose يفترض 8080 على المضيف ويربطه بالمنفذ 3000 داخل الحاوية؛ GitLab ليس ضمن Compose الخاص بالتطبيق.

## المتغيرات في GitLab Settings → CI/CD → Variables

| المتغير | النوع | الغرض |
| --- | --- | --- |
| DEPLOY_ENABLED | Variable | `true` فقط بعد تجهيز الخادم؛ غيابه يعطل النشر |
| DEPLOY_HOST | Variable، Protected | اسم DNS أو IPv4 لخادم النشر |
| DEPLOY_USER | Variable، Protected | حساب SSH على الخادم |
| SSH_PRIVATE_KEY | File، Protected | مفتاح حساب النشر، دون passphrase للتشغيل الآلي؛ لا يرفع إلى Git |
| SSH_KNOWN_HOSTS | File، Protected | مفاتيح المضيف التي جرى التحقق منها |
| APP_PORT | Variable اختياري | منفذ المضيف، الافتراضي 8080 |

CI_REGISTRY وCI_REGISTRY_IMAGE وCI_REGISTRY_USER وCI_REGISTRY_PASSWORD وCI_COMMIT_SHA وCI_PIPELINE_URL متغيرات GitLab المدمجة؛ لا تكتب قيمًا سرية في الملفات. IMAGE_TAG يحسب تلقائيًا من registry وcommit. عطّل debug tracing عند استخدام الأسرار.

## المزامنة إلى GitLab

بعد مراجعة وcommit التغييرات في GitHub، ومن جذر نسخة المستودع النظيفة:

```bash
bash scripts/publish-sample.sh git@YOUR-GITLAB:GROUP/sample-app.git main
```

استبدل العنوان والفرع بالقيم المتفق عليها. السكربت يستخدم git subtree لإرسال سجل sample-app بحيث يصبح هذا المجلد جذر GitLab، بما فيه .gitlab-ci.yml وci/ وdeploy/. يلزم Git مع subtree ووصول SSH إلى المشروع. لا يرسل docs/؛ تبقى وثائق الفريق على GitHub.

الدفع قد يبدأ Pipeline؛ لا تشغّل الأمر قبل تنسيق مشروع GitLab والمتغيرات مع العضو ٢. لا توجد مزامنة تلقائية. الدفع لا يستخدم force؛ إذا وجد تاريخ متعارض، يتوقف وتراجع طريقة توحيد السجل مع الفريق. شغّل المزامنة بعد كل تغيير معتمد تريد اختباره.

## التحقق والتسليم

- فحص صياغة shell بـShellCheck وفحص Compose بمتغير IMAGE_TAG تجريبي.
- فحص YAML محليًا لا يعوض GitLab CI Lint على إصدار GitLab الفعلي.
- عند جاهزية GitLab: CI Lint، ثم Pipeline بميزة النشر معطلة، ثم اختبار فشل الاختبارات والفحص الأمني للتأكد من حجب Deploy.
- بعدها فعّل النشر وتحقق من /health خارجيًا، واحتفظ برابط Pipeline ودليل الاستجابة. هذه خطوات تكامل لم تنفذ بعد.
- المراجع: العضو ٣ للأوامر والاختبارات، والعضو ٢ للـRunner والنشر.

## مراجع التصميم

- Docker-in-Docker مع TLS: https://docs.gitlab.com/ci/docker/docker_in_docker/
- فحص الصور وخيارات Trivy: https://trivy.dev/docs/dev/references/configuration/cli/trivy_image/

### نتائج الفحص المحلي — 15 سبتمبر 2026

- نجح تحليل ملفي YAML باستخدام Ruby Psych.
- نجح ShellCheck لسكربتي النشر والمزامنة، ونجح `git diff --check`.
- نجح `docker compose config --quiet` مع IMAGE_TAG تجريبي دون تشغيل حاويات.
- تحقق توقف سكربت المزامنة عند غياب المعاملات أو استخدام رابط غير SSH، وتوقف سكربت النشر عند غياب DEPLOY_HOST.
- نجح `npm ci` واختبارات التطبيق الأربعة، وبناء صورة Docker وتشغيلها وفحص `/health`.
- لم يُنفذ GitLab CI Lint أو دفع المزامنة أو نشر فعلي على Azure.

## تقدم الاختبار المحلي

نجحت تجربة Compose محلية مستقلة بتطبيق مؤقت: قبول HTTP 200 مع JSON صالح، ورفض HTTP 503 وJSON غير صالح. أزيلت حاويات وشبكة التجربة. راجع [خطة الاختبار ونتائجه](integration-test-plan.md) وطريقة إعادة التشغيل. لم يختبر اتصال SSH أو GitLab؛ متطلبات التكامل أعلاه ما زالت قائمة.

وفي 17 سبتمبر 2026، نجحت أيضًا اختبارات التطبيق الحقيقي، وبناء صورته وتشغيلها، ثم تشغيلها عبر Compose الفعلي ووصولها إلى `Healthy` مع الاستجابة `{"status":"ok","service":"foxflow-sample"}`.
