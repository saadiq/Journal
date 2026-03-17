(function () {
    pagination(false);
    insertConsultingCTA();
})();

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

    // Shift past headings to avoid breaking heading→paragraph flow
    for (var i = 0; i < 3 && index < children.length; i++) {
        var tag = children[index].tagName;
        if (tag === 'H2' || tag === 'H3' || tag === 'H4' || tag === 'H5' || tag === 'H6') {
            index++;
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
