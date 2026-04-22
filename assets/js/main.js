(function () {
    pagination(false);
    insertConsultingCTA();
    wireShareBar();
})();

function wireShareBar() {
    var buttons = document.querySelectorAll('.gh-share-bar [data-share-copy]');
    buttons.forEach(function (btn) {
        btn.addEventListener('click', function (e) {
            e.preventDefault();
            var url = window.location.href;
            var restore = function () { btn.removeAttribute('data-copied'); };
            var done = function () {
                btn.setAttribute('data-copied', 'true');
                setTimeout(restore, 2000);
            };
            if (navigator.clipboard && navigator.clipboard.writeText) {
                navigator.clipboard.writeText(url).then(done).catch(function () {
                    fallbackCopy(url, done);
                });
            } else {
                fallbackCopy(url, done);
            }
        });
    });
}

function fallbackCopy(text, done) {
    var ta = document.createElement('textarea');
    ta.value = text;
    ta.setAttribute('readonly', '');
    ta.style.position = 'fixed';
    ta.style.top = '-9999px';
    document.body.appendChild(ta);
    ta.select();
    try { document.execCommand('copy'); done(); } catch (err) { /* noop */ }
    document.body.removeChild(ta);
}

function insertConsultingCTA() {
    if (!document.body.classList.contains('post-template')) return;

    var source = document.getElementById('consulting-cta-source');
    if (!source) return;

    var content = document.querySelector('.gh-content');
    if (!content) return;

    var aside = source.querySelector('.consulting-cta');
    if (!aside) return;

    var children = Array.prototype.filter.call(content.children, function (el) {
        return el.tagName !== 'SCRIPT';
    });

    var clone = aside.cloneNode(true);

    if (children.length < 6) {
        content.appendChild(clone);
        return;
    }

    var index = Math.floor(children.length * 0.75);

    var isHeading = function (el) {
        if (!el) return false;
        var t = el.tagName;
        return t === 'H2' || t === 'H3' || t === 'H4' || t === 'H5' || t === 'H6';
    };

    // Avoid orphaning a section heading: if the element BEFORE the insertion
    // point is a heading, walk forward past the heading and its first few
    // paragraphs of content. If the element AT the insertion point is a
    // heading, insert BEFORE it so the heading starts the next section.
    for (var guard = 0; guard < 6 && index > 0 && index < children.length; guard++) {
        var prev = children[index - 1];
        var cur = children[index];
        if (isHeading(prev)) {
            index++;
        } else if (isHeading(cur)) {
            break;
        } else {
            break;
        }
    }

    if (index < children.length) {
        content.insertBefore(clone, children[index]);
    } else {
        content.appendChild(clone);
    }
}
